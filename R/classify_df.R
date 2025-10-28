#' Classify text using categories provided in a data frame
#'
#' @description
#' `classify_df()` is a thin wrapper around [classify_llm()] that accepts a
#' tidy table of categories (and optional descriptions) instead of separate
#' vectors. It appends the predicted category (and, optionally, probabilities)
#' to the input data.
#'
#' @param .data A data.frame/tibble containing the text to classify.
#' @param text_col Column in `.data` with the text to classify (tidy-eval).
#' @param categories A data.frame/tibble of category definitions.
#' @param category_col Column name in `categories` holding category labels
#'   (default `"category"`).
#' @param description_col Column name in `categories` with category descriptions
#'   (default `"description"`). If missing/NULL, categories are passed without
#'   descriptions.
#' @param id_col Optional column in `.data` to carry through as an identifier
#'   (useful for joins/debugging).
#' @param return_probs Logical; if `TRUE`, returns a long-format table of
#'   per-category probabilities joined back to `.data` (one row per text ×
#'   category). If `FALSE` (default), only the top prediction and its score are
#'   added.
#' @param .progress Logical; show a progress bar when classifying many rows.
#'   Default: `interactive()`.
#' @param ... Additional arguments forwarded to [classify_llm()] (e.g. `model`,
#'   `temperature`, `top_n`, `seed`, `system_prompt`, etc.).
#'
#' @returns
#' If `return_probs = FALSE` (default): `.data` with two new columns:
#' - `.pred_category` (chr)
#' - `.pred_score` (dbl; interpretation depends on the underlying model)
#'
#' If `return_probs = TRUE`: a tibble with `.data` columns plus:
#' - `.category` (chr)
#' - `.prob` (dbl)
#'
#' @examples
#' \dontrun{
#' library(dplyr)
#' texts <- tibble::tibble(id = 1:3,
#'   content = c(
#'     "Food distribution in border camp delayed by insecurity.",
#'     "Price inflation accelerates in host communities.",
#'     "Asylum application processing times decrease.")
#' )
#'
#' cats <- tibble::tribble(
#'   ~category,       ~description,
#'   "Protection",    "Risks, incidents, access to territory/asylum, GBV/CP",
#'   "Basic Needs",   "Shelter, food, WASH, core relief items",
#'   "Livelihoods",   "Jobs, income, markets, prices",
#'   "Procedures",    "RSD, documentation, processing, status"
#' )
#'
#' # Top prediction per row
#' texts |> classify_df(content, categories = cats, model = "gpt-4o-mini")
#'
#' # Full probability table
#' texts |> classify_df(content, categories = cats, return_probs = TRUE)
#' }
#'
#' @export
classify_df <- function(.data,
                        text_col,
                        categories,
                        category_col = "category",
                        description_col = "description",
                        id_col = NULL,
                        return_probs = FALSE,
                        .progress = interactive(),
                        ...) {
  
  # Imports we use without forcing users to attach
  requireNamespace("rlang", quietly = TRUE)
  requireNamespace("dplyr", quietly = TRUE)
  requireNamespace("purrr", quietly = TRUE)
  requireNamespace("tidyr", quietly = TRUE)
  requireNamespace("tibble", quietly = TRUE)
  
  # Tidy-eval capture
  text_col <- rlang::ensym(text_col)
  if (!is.null(id_col)) id_col <- rlang::ensym(id_col)
  
  # Validate inputs -----------------------------------------------------------
  if (!is.data.frame(.data)) {
    stop("`.data` must be a data.frame or tibble.", call. = FALSE)
  }
  if (!is.data.frame(categories)) {
    stop("`categories` must be a data.frame or tibble.", call. = FALSE)
  }
  if (!category_col %in% names(categories)) {
    stop(sprintf("`categories` must have a column '%s'.", category_col), call. = FALSE)
  }
  if (!rlang::as_string(text_col) %in% names(.data)) {
    stop(sprintf("`.data` does not have a text column '%s'.", rlang::as_string(text_col)),
         call. = FALSE)
  }
  if (!is.null(description_col) && !description_col %in% names(categories)) {
    warning(sprintf("`description_col='%s'` not found; proceeding without descriptions.",
                    description_col), call. = FALSE)
    description_col <- NULL
  }
  
  # Build category vectors ----------------------------------------------------
  cats_vec <- categories[[category_col]] |> as.character()
  if (length(unique(cats_vec)) != length(cats_vec)) {
    warning("Duplicate category labels detected; duplicates may be merged by the model.",
            call. = FALSE)
  }
  
  desc_vec <- NULL
  if (!is.null(description_col)) {
    desc_vec <- categories[[description_col]] |> as.character()
  }
  
  # Extract text vector
  text_vec <- .data[[rlang::as_string(text_col)]]
  
  # Progress option
  .map <- if (.progress) purrr::map2 else purrr::map2
  
  # Call classify_llm row-wise -----------------------------------------------
  # We rely on classify_llm() to accept:
  #   text, categories, descriptions (optional), and ...
  # and to return either:
  #   - a list with fields `label` and `score`, or
  #   - a list/data.frame with per-category probabilities when requested via ...
  #
  # To be robust, we standardize outputs here.
  #
  get_one <- function(x) {
    res <- classify_llm(
      text        = x,
      categories  = cats_vec,
      descriptions = desc_vec,
      ... # forward model/options
    )
    res
  }
  
  results <- if (.progress) {
    pb <- utils::txtProgressBar(min = 0, max = length(text_vec), style = 3)
    on.exit(close(pb), add = TRUE)
    purrr::imap(text_vec, function(tx, i) { utils::setTxtProgressBar(pb, i); get_one(tx) })
  } else {
    purrr::map(text_vec, get_one)
  }
  
  # Coerce outputs ------------------------------------------------------------
  # Strategy:
  # 1) If user asked for return_probs, try to get a prob vector per row and pivot longer.
  #    We attempt multiple common shapes to be resilient:
  #    - named numeric vector
  #    - data.frame with columns category/prob
  #    - list with $probs (named numeric)
  # 2) Else, try to get a top label + score:
  #    - list with $label, $score
  #    - data.frame with top row
  #    - choose max from a prob vector
  #
  as_probs_tbl <- function(r) {
    if (is.list(r) && !is.null(r$probs) && is.numeric(r$probs)) {
      tibble::tibble(.category = names(r$probs), .prob = as.numeric(r$probs))
    } else if (is.numeric(r) && !is.null(names(r))) {
      tibble::tibble(.category = names(r), .prob = as.numeric(r))
    } else if (is.data.frame(r) && all(c(category_col, "prob") %in% names(r))) {
      rlang::set_names(r[, c(category_col, "prob")], c(".category", ".prob"))
    } else if (is.data.frame(r) && all(c("category", "prob") %in% names(r))) {
      rlang::set_names(r[, c("category", "prob")], c(".category", ".prob"))
    } else {
      NULL
    }
  }
  
  as_top_tbl <- function(r) {
    # Case 1: labeled list
    if (is.list(r) && !is.null(r$label)) {
      tibble::tibble(.pred_category = as.character(r$label),
                     .pred_score    = if (!is.null(r$score)) as.numeric(r$score) else NA_real_)
      # Case 2: probs exist → take argmax
    } else if (!is.null(as_probs_tbl(r))) {
      p <- as_probs_tbl(r)
      p <- p[which.max(p$.prob), , drop = FALSE]
      tibble::tibble(.pred_category = p$.category, .pred_score = p$.prob)
      # Case 3: data.frame with 'label' and maybe 'score'
    } else if (is.data.frame(r) && "label" %in% names(r)) {
      tibble::tibble(.pred_category = as.character(r$label[[1]]),
                     .pred_score    = if ("score" %in% names(r)) as.numeric(r$score[[1]]) else NA_real_)
    } else {
      tibble::tibble(.pred_category = NA_character_, .pred_score = NA_real_)
    }
  }
  
  if (isTRUE(return_probs)) {
    probs_list <- purrr::map(results, as_probs_tbl)
    if (any(purrr::map_lgl(probs_list, is.null))) {
      warning("Could not extract probability vectors for some rows; ",
              "falling back to top prediction for those.", call. = FALSE)
    }
    # Build long table
    out <- dplyr::bind_rows(
      purrr::imap(probs_list, function(tbl, i) {
        base <- .data[i, , drop = FALSE]
        if (is.null(tbl)) {
          # fallback to top
          top <- as_top_tbl(results[[i]])
          dplyr::bind_cols(base, tibble::tibble(.category = top$.pred_category,
                                                .prob     = top$.pred_score))
        } else {
          dplyr::bind_cols(base[rep(1, nrow(tbl)), , drop = FALSE], tbl)
        }
      })
    )
    if (!is.null(id_col)) {
      out <- dplyr::relocate(out, !!id_col, .before = dplyr::everything())
    }
    return(out)
  } else {
    tops <- purrr::map_dfr(results, as_top_tbl)
    out  <- dplyr::bind_cols(.data, tops)
    if (!is.null(id_col)) {
      out <- dplyr::relocate(out, !!id_col, .before = dplyr::everything())
    }
    return(out)
  }
}
