#' mist
#'
#' Test for association between a set of SNPS/genes and continuous outcomes by
#' including variant characteristic information and using score statistics.
#'
#' @param y [[numeric]] A `numeric` vector of the continuous outcome variables. Missing values are not allowed.
#' @param X [[numeric]] A `numeric` matrix of covariates with rows for individuals and columns for covariates.
#'   If there is no covariate, it does not need to be specified
#' @param G [[numeric]] A `numeric` genotype matrix with rows for individuals and columns for SNPs.
#'   Each SNP should be coded as 0, 1, and 2 for AA, Aa, aa, where A is a major allele and a is a minor allele.
#'   Missing genotypes are not allowed.
#' @param Z [[numeric]] a `numeric` matrix of second level covariates for variant characteristics.
#'   Each row corresponds to a variant and each column corresponds to a variant characteristic.
#'   If there is no second level covariates, a vector of 1 should be used.
#' @param method [[character]] A method to compute the p-value and the default value is "liu".
#'   Method "davies" represents an exact method that computes the p-value
#'     by inverting the characteristic function of the mixture chisq.
#'   Method "liu" represents an approximation method that matches the first 3 moments.
#' @param model [[character]] A `character` vector specifying the model. Default is to `"guess"`.
#'   Possible choices are `"guess"`, `"continuous"` (linear regression) or `"binary"` (logistic regression).
#' @param weight.beta [[numeric]] A `numeric` vector of parameters of beta function
#'   which is the weight for scorestatistics.
#'   The default value is `NULL`, *i.e.* no weight.
#'   Default weight value could be `c(1, 25)`.
#' @param maf [[numeric]] A `numeric` vector of MAF (minor allele frequency) for each SNP.
#'
#' @return
#' * S.tau score Statistic for the variant heterogeneous effect.
#' * S.pi score Statistic for the variant mean effect.
#' * p.value.S.tau P-value for testing the variant heterogeneous effect.
#' * p.value.S.pi P-value for testing the variant mean effect.
#' * p.value.overall Overall p-value for testing the association between the set of SNPS/genes and outcomes.
#'   It combines p.value.S.pi and p.value.S.tau by using Fisher's procedure.
#'
#' @export
#'
#' @examples
#'
#' library(MiSTr)
#' data(mist_data)
#' attach(mist_data)
#'
#' mist(
#'   y = phenotypes[, "y_taupi"],
#'   X = phenotypes[, paste0("x_cov", 0:2)],
#'   G = genotypes,
#'   Z = variants_info[, 1, drop = FALSE]
#' )
#'
#' mist(
#'   y = phenotypes[, "y_binary"],
#'   X = phenotypes[, paste0("x_cov", 0:2)],
#'   G = genotypes,
#'   Z = variants_info[, 1, drop = FALSE]
#' )
#'
mist <- function(
  y, X, G, Z,
  method = "liu",
  model = c("guess", "continuous", "binary"),
  weight.beta = NULL, # c(1, 25)
  maf = NULL
) {
  model <- match.arg(model, c("guess", "continuous", "binary"))
  method <- match.arg(method, c("liu", "davies"))

  check_y <- c("continuous", "binary")[(length(unique(y)) == 2) + 1]
  if (any(grepl("guess", model))) {
    message('[MiSTr] "y" seems to be "', check_y, '", model is set to "', check_y, '"!')
    model <- check_y
  }
  if (model != check_y) {
    warning('[MiSTr] "y" seems to be "', check_y, '" and model was set to "', model, '"!')
  }
  output <- switch(
    EXPR = model,
    "continuous" = {
      message(paste("[MiSTr] Linear regression is ongoing ..."))
      tidy_mist(suppressMessages(mist_linear(y, X, G, Z, method, weight.beta, maf)))
    },
    "binary" = {
      message("[MiSTr] Logistic regression is ongoing ...")
      tidy_mist(suppressMessages(mist_logit(y, X, G, Z, method, weight.beta, maf)))
    }
  )
  class(output) <- "mist"
  output
}


#' tidy_mist / mist_print
#'
#' @param x [[mist]]
#'
#' @keywords internal
#' @usage NULL
#'
#' @return list
tidy_mist <- function(x) {
  cluster_name <- sub("^M", "", rownames(x$out_estimate))
  rownames(x$out_estimate) <- NULL
  stat_rare <- cbind.data.frame(
    "SubClusters" = ifelse(cluster_name == "", "None", cluster_name),
    x$out_estimate
  )

  list(estimate = stat_rare, statistics = as.data.frame(x$out_statistics))
}


#' Print method for mist objec
#'
#' @param x [[mist]]
#' @param ... Other arguments (Not used).
#'
#' @return list
#' @export
print.mist <- function(x, ...) {
  terms_columns <- grep("SubClusters|term.pi.hat", names(x$estimate))
  x$estimate[, -terms_columns] <- round(x$estimate[, -terms_columns], digits = 3)

  cat(
    "",
    "MiSTr: Mixed effects Score Test",
    "-------------------------------",
    "",
    "- (Raw) Estimates:",
    "",
    sep = "\n"
  )

  print.data.frame(x$estimate)

  cat(
    "\n",
    "- Statistics:",
    "\n\n",
    "  + Overall effect: ",
    "\n",
    "    * P-value = ", format.pval(x$statistics[, "p.value.overall"], digits = 3),
    "\n",
    "  + PI (mean effect):  ",
    "\n",
    "    * Score = ", round(x$statistics[, "S.pi"], digits = 3),
    "\n",
    "    * P-value = ", format.pval(x$statistics[, "p.value.S.pi"], digits = 3),
    "\n",
    "  + TAU (heterogeneous effect):  ",
    "\n",
    "    * Score = ", round(x$statistics[, "S.tau"], digits = 3),
    "\n",
    "    * P-value = ", format.pval(x$statistics[, "p.value.S.tau"], digits = 3),
    "\n\n",
    sep = ""
  )

  invisible(x)
}


#' mist_logit
#'
#' @inheritParams mist
#'
#' @keywords internal
#' @usage NULL
#'
#' @importFrom broom tidy
#'
#' @return data.frame
mist_logit <- function(y, X, G, Z, method = "liu", weight.beta = NULL, maf = NULL) {
  method <- match.arg(method, c("liu", "davies"))
  if (!is.vector(y, "numeric")) stop('[MiSTr] "y" must be a numeric vector.')
  if (!(is.matrix(X) & is.numeric(X))) stop('[MiSTr] "X", must be a numeric matrix.')
  if (!(is.matrix(G) & is.numeric(G))) stop('[MiSTr] "G", must be a numeric matrix.')
  if (!(is.matrix(Z) & is.numeric(Z))) stop('[MiSTr] "Z", must be a numeric matrix.')
  if ((is.null(weight.beta) | is.null(maf)) & !all(is.null(c(weight.beta, maf)))) {
    warning('[MiSTr] Both or none of "weight.beta" and "maf" must be provided.')
    message('[MiSTr] Falling back to default with "weight.beta = NULL" and "maf = NULL".')
  }

  GZ <- G %*% Z
  M <- cbind(X, GZ)

  fit.0 <- stats::glm(
    formula = y ~ X - 1,
    family = stats::binomial(link = "logit")
  )
  mu.0 <- fit.0$fitted.value
  d.0 <- mu.0 * (1 - mu.0)
  res.0 <- y - mu.0

  fit.0a <- stats::glm(
    formula = y ~ -1 + X + GZ,
    family = stats::binomial(link = "logit")
  )
  mu.0a <- fit.0a$fitted.value
  d.0a <- mu.0a * (1 - mu.0a)
  res.0a <- y - mu.0a

  D.0 <- diag(d.0)
  D.0a <- diag(d.0a)

  tXD0X <- t(X) %*% D.0 %*% X
  inv.tXD0X <- solve(tXD0X)

  tMD0aM <- t(M) %*% D.0a %*% M
  inv.tMD0aM <- solve(tMD0aM)

  P01 <- D.0 - (d.0 %o% d.0) * (X %*% (inv.tXD0X) %*% t(X))
  P02 <- D.0a - (d.0a %o% d.0a) * (M %*% (inv.tMD0aM) %*% t(M))

  if (is.null(weight.beta) | is.null(maf)) {
    S.tau <- 0.5 * t(res.0a) %*% G %*% t(G) %*% res.0a
  } else {
    W <- diag(stats::dbeta(maf, weight.beta[1], weight.beta[2])^2)
    S.tau <- 0.5 * t(res.0a) %*% G %*% W %*% t(G) %*% res.0a
  }

  inv.I.pi <- solve(t(GZ) %*% P01 %*% GZ)

  S.pi <- t(res.0) %*% GZ %*% inv.I.pi %*% t(GZ) %*% res.0

  p.value.S.pi <- 1 - stats::pchisq(S.pi, df = dim(Z)[2])

  if (is.null(weight.beta) | is.null(maf)) {
    Mat <- 0.5 * t(G) %*% P02 %*% G
  } else {
    Mat <- 0.5 * sqrt(W) %*% t(G) %*% P02 %*% G %*% sqrt(W)
  }
  lambda <- eigen(Mat, symmetric = TRUE)$values

  p.value.S.tau <- switch(EXPR = method,
    "davies" = {
      tryCatch(
        expr = CompQuadForm::davies(S.tau, lambda)$Qq,
        error = function(e) NA
      )
    },
    "liu" = {
      tryCatch(
        expr = CompQuadForm::liu(S.tau, lambda),
        error = function(e) NA
      )
    }
  )

  q.fisher <- -2 * (log(p.value.S.tau) + log(p.value.S.pi))
  p.value.overall <- 1 - stats::pchisq(q.fisher, df = 4)

  out_statistics <- list(
    S.pi = S.pi,
    p.value.S.pi = p.value.S.pi,
    S.tau = S.tau,
    p.value.S.tau = p.value.S.tau,
    p.value.overall = p.value.overall
  )

  out_estimate <- broom::tidy(fit.0a, conf.int = TRUE, exponentiate = TRUE)
  out_estimate <- out_estimate[grep(paste(c("^GZ$", colnames(GZ)), collapse = "|"), out_estimate[["term"]]), ]
  colnames(out_estimate) <- sprintf("%s.pi.hat", colnames(out_estimate))

  list(out_statistics = out_statistics, out_estimate = out_estimate)
}


#' mist_linear
#'
#' @inheritParams mist
#'
#' @keywords internal
#' @usage NULL
#'
#' @importFrom broom tidy
#'
#' @return data.frame
mist_linear <- function(y, X, G, Z, method = "liu", weight.beta = NULL, maf = NULL) {
  method <- match.arg(method, c("liu", "davies"))
  if (!is.vector(y, "numeric")) stop('"y" must be a numeric vector.')
  if (!(is.matrix(G) & is.numeric(G))) stop('"G", must be a numeric matrix.')
  if (!(is.matrix(X) & is.numeric(X))) stop('"X", must be a numeric matrix.')
  if (!(is.matrix(Z) & is.numeric(Z))) stop('"Z", must be a numeric matrix.')
  if ((is.null(weight.beta) | is.null(maf)) & !all(is.null(c(weight.beta, maf)))) {
    warning('[MiSTr] Both or none of "weight.beta" and "maf" must be provided.')
    message('[MiSTr] Falling back to default with "weight.beta = NULL" and "maf = NULL".')
  }

  GZ <- G %*% Z
  M <- cbind(X, GZ)

  tXX <- t(X) %*% X
  inv.tXX <- solve(tXX)

  tMM <- t(M) %*% M
  inv.tMM <- solve(tMM)

  fit.0 <- stats::lm(y ~ X - 1)
  tilde.sigma2 <- summary(fit.0)$sigma^2
  res.0 <- fit.0$resid

  fit.0a <- stats::lm(y ~ M - 1)
  hat.sigma2 <- summary(fit.0a)$sigma^2
  res.0a <- fit.0a$resid

  n <- dim(X)[1]
  I <- diag(1, n)

  P2 <- I - X %*% inv.tXX %*% t(X)
  P1 <- I - M %*% inv.tMM %*% t(M)

  if (is.null(weight.beta) | is.null(maf)) {
    S.tau <- t(res.0a) %*% G %*% t(G) %*% res.0a
  } else {
    W <- diag(stats::dbeta(maf, weight.beta[1], weight.beta[2])^2)
    S.tau <- t(res.0a) %*% G %*% W %*% t(G) %*% res.0a
  }

  inv.I.pi <- solve(t(GZ) %*% P2 %*% GZ)

  S.pi <- t(res.0) %*% GZ %*% inv.I.pi %*% t(GZ) %*% res.0
  S.pi <- S.pi / tilde.sigma2

  p.value.S.pi <- 1 - stats::pchisq(S.pi, df = dim(Z)[2])

  if (is.null(weight.beta) | is.null(maf)) {
    P1.G <- P1 %*% G
  } else {
    P1.G <- P1 %*% G %*% sqrt(W)
  }
  Mat <- (hat.sigma2) * t(P1.G) %*% P1.G
  lambda <- eigen(Mat, symmetric = TRUE)$values

  p.value.S.tau <- switch(EXPR = method,
    "davies" = {
      tryCatch(
        expr = CompQuadForm::davies(S.tau, lambda)$Qq,
        error = function(e) NA
      )
    },
    "liu" = {
      tryCatch(
        expr = CompQuadForm::liu(S.tau, lambda),
        error = function(e) NA
      )
    }
  )

  q.fisher <- -2 * (log(p.value.S.tau) + log(p.value.S.pi))
  p.value.overall <- 1 - stats::pchisq(q.fisher, df = 4)

  out_statistics <- list(
    S.pi = S.pi,
    p.value.S.pi = p.value.S.pi,
    S.tau = S.tau,
    p.value.S.tau = p.value.S.tau,
    p.value.overall = p.value.overall
  )

  out_estimate <- broom::tidy(fit.0a, conf.int = TRUE, exponentiate = FALSE)
  out_estimate <- out_estimate[grep(paste(c("^GZ$", colnames(GZ)), collapse = "|"), out_estimate[["term"]]), ]
  colnames(out_estimate) <- sprintf("%s.pi.hat", colnames(out_estimate))

  list(out_statistics = out_statistics, out_estimate = out_estimate)
}
