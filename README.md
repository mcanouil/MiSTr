
<!-- README.md is generated from README.Rmd. Please edit that file -->

# *Mi*xed effects *S*core *T*est <img src="man/figures/mistr.png" align="right" width="120" />

<!-- badges: start -->

[![Lifecycle:
stable](https://img.shields.io/badge/lifecycle-stable-brightgreen.svg)](https://www.tidyverse.org/lifecycle/#stable)
[![GitHub
tag](https://img.shields.io/github/tag/mcanouil/MiSTr.svg?label=latest%20tag)](https://github.com/mcanouil/MiSTr)
[![R build
status](https://github.com/mcanouil/MiSTr/workflows/R-CMD-check/badge.svg)](https://github.com/mcanouil/MiSTr/actions)
[![Coverage Status
(codecov)](https://codecov.io/gh/mcanouil/MiSTr/branch/master/graph/badge.svg)](https://codecov.io/gh/mcanouil/MiSTr)
<!-- badges: end -->

Test for association between a set of SNPS/genes and continuous or
binary outcomes by including variant characteristic information and
using (weighted) score statistics.

**Note:**

  - From: <https://cran.r-project.org/src/contrib/MiST_1.0.tar.gz>
  - Reference: <https://doi.org/10.1002/gepi.21717>

## Installation

``` r
# Install MiSTr from CRAN:
install.packages("MiSTr")

# Or the the development version from GitHub:
# install.packages("remotes")
remotes::install_github("mcanouil/MiSTr")
```

## MiSTr in Action

``` r
library(MiSTr)
data(mist_data)
attach(mist_data)
```

### Continuous Outcome

``` r
res <- mist(
  y = phenotypes[, "y_taupi"],
  X = phenotypes[, paste0("x_cov", 0:2)],
  G = genotypes,
  Z = variants_info[, 1, drop = FALSE]
)
#> [MiSTr] "y" seems to be "continuous", model is set to "continuous"!
#> [MiSTr] Linear regression is ongoing ...
str(res)
#> List of 2
#>  $ estimate  :'data.frame':  1 obs. of  5 variables:
#>   ..$ SubClusters: chr "cluster1"
#>   ..$ Pi_hat     : num 0.248
#>   ..$ SE         : num 0.321
#>   ..$ CI_2.5     : num -0.389
#>   ..$ CI_97.5    : num 0.885
#>  $ statistics:'data.frame':  1 obs. of  5 variables:
#>   ..$ S.pi           : num 0.601
#>   ..$ p.value.S.pi   : num 0.438
#>   ..$ S.tau          : num 1006
#>   ..$ p.value.S.tau  : num 0.0111
#>   ..$ p.value.overall: num 0.0307
#>  - attr(*, "class")= chr "mist"
print(res)
#> 
#> MiSTr: Mixed effects Score Test
#> -------------------------------
#> 
#> - (Raw) Estimates:
#> 
#>   SubClusters Pi_hat    SE CI_2.5 CI_97.5
#> 1    cluster1  0.248 0.321 -0.389   0.885
#> 
#> - Statistics:
#> 
#>   + Overall effect: 
#>     * P-value = 0.0307
#>   + PI (mean effect):  
#>     * Score = 0.601
#>     * P-value = 0.438
#>   + TAU (heterogeneous effect):  
#>     * Score = 1006.125
#>     * P-value = 0.0111
```

### Binary Outcome

``` r
res <- mist(
  y = phenotypes[, "y_binary"],
  X = phenotypes[, paste0("x_cov", 0:2)],
  G = genotypes,
  Z = variants_info[, 1, drop = FALSE]
)
#> [MiSTr] "y" seems to be "binary", model is set to "binary"!
#> [MiSTr] Logistic regression is ongoing ...
str(res)
#> List of 2
#>  $ estimate  :'data.frame':  1 obs. of  6 variables:
#>   ..$ SubClusters: chr "cluster1"
#>   ..$ Pi_hat     : num 1.27
#>   ..$ SE         : num 0.344
#>   ..$ CI_2.5     : num 0.66
#>   ..$ CI_97.5    : num 2.02
#>   ..$ OR         : num 3.58
#>  $ statistics:'data.frame':  1 obs. of  5 variables:
#>   ..$ S.pi           : num 17.5
#>   ..$ p.value.S.pi   : num 2.83e-05
#>   ..$ S.tau          : num 5.4
#>   ..$ p.value.S.tau  : num 0.175
#>   ..$ p.value.overall: num 6.54e-05
#>  - attr(*, "class")= chr "mist"
print(res)
#> 
#> MiSTr: Mixed effects Score Test
#> -------------------------------
#> 
#> - (Raw) Estimates:
#> 
#>   SubClusters Pi_hat    SE CI_2.5 CI_97.5    OR
#> 1    cluster1  1.274 0.344   0.66   2.019 3.576
#> 
#> - Statistics:
#> 
#>   + Overall effect: 
#>     * P-value = 6.54e-05
#>   + PI (mean effect):  
#>     * Score = 17.527
#>     * P-value = 2.83e-05
#>   + TAU (heterogeneous effect):  
#>     * Score = 5.4
#>     * P-value = 0.175
```
