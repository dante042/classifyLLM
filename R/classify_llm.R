#' Classify a character vector into predefined categories using an LLM
#'
#' Designed for tidyverse pipelines. Sends each element of \code{x} to the model
#' with a strict instruction to return exactly one label from \code{categories}.
#'
#' @param x Character vector to classify.
#' @param categories Character vector of allowed categories (labels).
#' @param model OpenAI model name. Default: "gpt-4o-mini".
#' @param temperature Numeric in [0,1]; default 0 for deterministic outputs.
#' @param batch_size Integer; number of elements per API call batch. Default 1.
#' @param delay Seconds to sleep between batches to avoid rate limits. Default 0.
#' @param verbose Logical; print progress info. Default FALSE.
#' @return A factor with levels = \code{categories}, aligned to input length.
#' @examples
#' \dontrun{
#' Sys.setenv(OPENAI_API_KEY = "sk-...")
#' classify_llm(
#'   x = c("siamese kitty","golden retriever","parakeet"),
#'   categories = c("cat","dog","bird")
#' )
#' }
#' @export
classify_llm <- function(
  x,
  categories,
  model = "gpt-4o-mini",
  temperature = 0,
  batch_size = 1L,
  delay = 0,
  verbose = FALSE
) {
  stopifnot(is.character(x) || is.factor(x))
  x <- as.character(x)
  stopifnot(is.character(categories), length(categories) >= 2L)

  taxonomy <- paste0("- ", categories, collapse = "\n")
  system_msg <- glue::glue(
    "You are a strict classifier. Return exactly one label from the allowed set.\n",
    "Allowed labels:\n{taxonomy}\n\n",
    "Rules:\n",
    "- Return only the label text with no extra words.\n",
    "- If uncertain, choose the closest label by meaning.\n",
    "- Do not invent new labels.\n"
  )

  classify_one <- function(txt) {
    user_msg <- glue::glue(
      "Text: {txt}\n",
      "Pick exactly one of: {paste(categories, collapse = ', ')}"
    )

    out <- openai_chat(
      messages = list(
        list(role = "system", content = system_msg),
        list(role = "user",   content = user_msg)
      ),
      model = model,
      temperature = temperature
    )

    out <- stringr::str_trim(out)

    if (!out %in% categories) {
      idx <- which(tolower(categories) == tolower(out))
      if (length(idx) == 1) out <- categories[idx]
    }
    if (!out %in% categories) {
      hits <- vapply(
        categories,
        function(cg) grepl(paste0("\\b", tolower(cg), "\\b"), tolower(out)),
        logical(1)
      )
      if (any(hits)) out <- categories[which(hits)[1]]
    }
    if (!out %in% categories) out <- categories[[1]]
    out
  }

  n <- length(x)
  idx <- seq_len(n)
  res <- character(n)

  if (batch_size <= 1L) {
    for (i in idx) {
      if (verbose) cli::cli_alert_info(sprintf("Classifying %d/%d", i, n))
      res[i] <- classify_one(x[i])
    }
  } else {
    batches <- split(idx, ceiling(seq_along(idx) / batch_size))
    for (b in seq_along(batches)) {
      ids <- batches[[b]]
      if (verbose) cli::cli_alert_info(
        sprintf("Batch %d/%d (%d items)", b, length(batches), length(ids))
      )
      for (i in ids) res[i] <- classify_one(x[i])
      if (delay > 0 && b < length(batches)) Sys.sleep(delay)
    }
  }

  factor(res, levels = categories)
}
