# R/compute-spa-negll.R
# Functions:
#   - get_nonAD_tvec_hat_vals(): Computes the t–vector when AD tracking is not needed.
#   - choose_negll_fun(): Selects the negative log–likelihood function based on a method.
#   - create_spa_taped_fun(): Constructs a taped function (i.e. a closure) that computes
#         the saddlepoint negative log–likelihood (and optionally its gradient/Hessian) while
#         capturing AD dependencies.
#         NOTE: When a user-supplied t–vector is provided, the returned tape is for
#         one–time use only.
#   - compute.spa.negll(): The main function that returns the saddlepoint negative
#         log–likelihood (and derivatives) for a given parameter vector.





# -----------------------------------------------------------------------------
# Compute tvec values (no tape needed)
# -----------------------------------------------------------------------------
#' @noRd
get_nonAD_tvec_hat_vals <- function(parameter_vector, 
                                    observed.data,
                                    cgf,
                                    user_tvec = NULL,
                                    ...) {
  if (!is.null(user_tvec)) return(user_tvec)
  if (cgf$has_analytic_tvec_hat()) return(cgf$analytic_tvec_hat(observed.data, parameter_vector))
  # Otherwise, solve numerically using the R-based saddlepoint.solve()
  saddlepoint.solve(theta = parameter_vector,
                    y     = observed.data,
                    cgf   = cgf,
                    ...)
}



# -----------------------------------------------------------------------------
# Generic function selector for saddlepoint-based computations.
# -----------------------------------------------------------------------------
#' @noRd
choose_spa_function <- function(spa_method, cgf) {
  allowed_methods <- c(
    "negll_standard",  
    "negll_zeroth",    
    "correction_standard",  
    "correction_zeroth"   
  ) ##### can expand in future?????
  ##### maybe the additional non-gaussian methods?
  
  if (!spa_method %in% allowed_methods) {
    stop(sprintf(
      "Unknown saddlepoint method '%s'. Allowed methods: %s",
      spa_method, paste(allowed_methods, collapse = ", ")
    ))
  }
  
  neg_ll_fun  <- cgf$.get_private_method("neg_ll")             # function(tvec, theta)
  tilt_fun    <- cgf$.get_private_method("tilting_exponent")     # function(tvec, theta)
  funcT_first <- cgf$.get_private_method("func_T")             # function(tvec, theta)
  
  
  # Return whichever function is appropriate:
  if (spa_method == "negll_standard") {
    # The full negative log-likelihood
    return(neg_ll_fun)
    
  } else if (spa_method == "negll_zeroth") {
    # The zeroth-order negative log-likelihood
    return(function(tvec, theta) -tilt_fun(tvec, theta))
    
  } else if (spa_method == "correction_standard") {
    # The first-order correction
    return(funcT_first)
    
  } else {
    # spa_method == "correction_zeroth" => the function computing -0.5 * log det(K2)
    return(function(tvec, theta) {
      K2_val <- cgf$K2(tvec, theta)
      -0.5 * determinant(K2_val, logarithm = TRUE)$modulus
    })
  }
}


# -----------------------------------------------------------------------------
# Build an AD-taped function for the saddlepoint-based computation.
# -----------------------------------------------------------------------------
# Constructs a taped function that computes the saddlepoint negative log–likelihood/or maybe the correction term???,
# its gradient, and, optionally, its Hessian. The tape captures the AD dependency for the
# entire computation.
# If a user–supplied t–vector (`user_tvec`) is provided, it is used (and its AD dependency is
# captured via the cpp's `tvec_hat_from_tvec()`). 
# Note that in this case the resulting tape is intended for one–time use only.
# NOTE: Additional arguments (...) are passed to saddlepoint.solve() only when no user_tvec
#       is provided, but they are not (yet) forwarded to the C++ functions. 

#' @noRd
create_spa_taped_fun <- function(param_vec,
                                 observed.data,
                                 cgf,
                                 spa_method, # spa_method is one of "negll_standard", "negll_zeroth", "correction_standard", "correction_zeroth"
                                 user_tvec = NULL,
                                 gradient = FALSE,
                                 hessian = FALSE,
                                 ... # additional arguments to saddlepoint.solve
) {
  
  if (hessian && !gradient) gradient <- TRUE
  chosen_spa_fn <- choose_spa_function(spa_method = spa_method, cgf = cgf)
  K2_solve_fn <- create_tvec_hat_K2_solve_fn(cgf)
  
  
  # We will make a tape of "local_fn". First we need to determine how tvec is availed (user-supplied, analytic, or numeric), and 
  # use the appropriate local_fn.
  
  if (!is.null(user_tvec)) {
    # CASE A: If user provided a numeric tvec, use it directly
    # The only issue with this branch is that we hope the resulting tape is used only once.
    # It's addition here is to help with standard error calculations; when MLEs.tvec has been obtained.
    local_fn <- function(par) {
      # We call the cpp's `tvec_hat_from_tvec()` to ensure correct AD dependency. 
      tvec_hat_vals <- tvec_hat_from_tvec(
        theta         = par,
        tvec          = user_tvec,
        observations  = observed.data,
        K1_fn         = cgf$K1,
        K2_solve_fn   = K2_solve_fn
      )
      chosen_spa_fn(tvec_hat_vals, par)
    }
  } else if(cgf$has_analytic_tvec_hat()) {
    # CASE B: If cgf has an analytic formula for tvec_hat, use it
    local_fn <- function(par) {
      tvec_vals <- cgf$analytic_tvec_hat(observed.data, par)
      chosen_spa_fn(tvec_vals, par)
    }
  } else {
    # CASE C: numeric solve each time
    #   Here we use another cpp function tapedSaddlepointSolve(), that internally calls saddlepoint.solve()
    #   The resulting tape from this senario internally knows to update the tvec values for each parameter vector.
    #   This is the general case, but can be slow.
    #   Other options would be to use a more efficient solver;
    ##### Maybe look into saddlepoint.solve() or a version of it living in cpp
    local_fn <- function(par) {
      tvec_hat_vals <- tapedSaddlepointSolve(
        theta         = par,
        observations  = observed.data,
        K2_solve_fn   = K2_solve_fn,
        saddlepoint_solve_fn = saddlepoint.solve,
        cgf_obj       = cgf
      )
      chosen_spa_fn(tvec_hat_vals, par)
    }
  }
  
  tape_obj <- MakeTape(f = local_fn, x = param_vec)
  if (hessian) jacfun_obj <- tape_obj$jacfun()
  
  function(theta) {
    list(
      vals     = tape_obj(theta),
      gradient = if(gradient) as.vector(tape_obj$jacobian(theta)) else NULL,
      hessian  = if(hessian) jacfun_obj$jacobian(theta) else NULL
    )
  }
  
}






#' Compute the saddlepoint negative log-likelihood
#'
#' @description
#' Computes either the "standard" or "zeroth-order" saddlepoint approximation to the negative log–likelihood.
#' 
#' **Note:** When a user–supplied t–vector is provided (via `tvec.hat`),
#' the resulting AD tape is intended for one–time use only.
#'
#' @param parameter_vector Numeric vector of parameters.
#' @param observed.data Numeric vector of observed data.
#' @param cgf A `CGF` object.
#' @param tvec.hat (Optional) numeric vector. If provided, it overrides other ways
#'        of finding `tvec`.
#' @param gradient Logical. If `TRUE`, the gradient is computed.
#' @param hessian Logical. If `TRUE`, the Hessian is computed.
#' @param spa_method Character string. One of `"standard"` or `"zeroth"`. 
#' @param ... Additional arguments passed to `saddlepoint.solve()` if `tvec.hat` is not provided.
#'
#' @return A named list with elements:
#' \describe{
#'   \item{vals}{Numeric scalar. The negative log-likelihood at `parameter_vector`.}
#'   \item{gradient}{Numeric vector. The gradient at `parameter_vector`, if `gradient=TRUE`.}
#'   \item{hessian}{The Hessian at `parameter_vector`, if `hessian=TRUE`.}
#' }
#' 
#' @seealso \code{\link{saddlepoint.solve}}
#'
#' @export
compute.spa.negll <- function(parameter_vector,
                              observed.data,
                              cgf,
                              tvec.hat = NULL,
                              gradient = FALSE,
                              hessian  = FALSE,
                              spa_method   = "standard",
                              ...) {
  if (!inherits(cgf, "CGF")) stop("`cgf` must be an object of class CGF")
  if (!is.numeric(parameter_vector)) stop("`parameter_vector` must be numeric.")
  if (!is.numeric(observed.data))    stop("`observed.data` must be numeric.")
  if (!is.null(tvec.hat) && !is.numeric(tvec.hat)) stop("`tvec.hat` must be numeric.")
  if (!is.logical(gradient) || length(gradient) != 1) stop("`gradient` must be a logical.")
  if (!is.logical(hessian) || length(hessian) != 1) stop("`hessian` must be a logical.")
  if (!is.character(spa_method) || length(spa_method) != 1) stop("`spa_method` must be a character string.")
  
  
  if (spa_method == "standard") {
    spa_method <- "negll_standard"
  } else if (spa_method == "zeroth") {
    spa_method <- "negll_zeroth"
  }
  
  
  
  # If no gradient/hessian needed => direct numeric eval
  if (!gradient && !hessian) {
    tvec_hat_vals <- get_nonAD_tvec_hat_vals(
      parameter_vector = parameter_vector,
      observed.data    = observed.data,
      cgf              = cgf,
      user_tvec        = tvec.hat,
      ...
    )
    chosen_negll <- choose_spa_function(spa_method = spa_method, cgf = cgf)
    val <- chosen_negll(tvec_hat_vals, parameter_vector)[1] ##### here, [1] strips off an attribute.
    return(list(vals = val, gradient = NULL, hessian = NULL))
  }
  
  
  # Otherwise, build an AD tape and return its evaluation.
  taped_fun <- create_spa_taped_fun(
    param_vec     = parameter_vector,
    observed.data = observed.data,
    cgf           = cgf,
    spa_method        = spa_method,
    user_tvec     = tvec.hat,
    gradient      = gradient,
    hessian       = hessian,
    ... #### addtional arguments are passed to saddlepoint.solve() are still not being passed to cpp
  )
  taped_fun(parameter_vector)
}









