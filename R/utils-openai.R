#' @keywords internal
get_openai_key <- function() {
  key <- Sys.getenv("OPENAI_API_KEY", unset = NA_character_)
  if (is.na(key) || !nzchar(key)) {
    cli::cli_abort(
      "No OpenAI API key found. Set {.env OPENAI_API_KEY} or use {.fn classifyLLM::set_openai_key}."
    )
  }
  key
}

#' Set OpenAI API Key
#' @param key Character string with your API key.
#' @export
set_openai_key <- function(key) {
  stopifnot(is.character(key), length(key) == 1L)
  Sys.setenv(OPENAI_API_KEY = key)
  invisible(TRUE)
}

#' @keywords internal
openai_chat <- function(messages, model = "gpt-4o-mini", temperature = 0, timeout = 60) {
  key <- get_openai_key()
  url <- "https://api.openai.com/v1/chat/completions"
  
  req <- httr2::request(url) |>
    httr2::req_headers(
      "Authorization" = paste("Bearer", key),
      "Content-Type"  = "application/json"
    ) |>
    httr2::req_body_json(list(
      model = model,
      messages = messages,
      temperature = temperature
    )) |>
    httr2::req_timeout(timeout)
  
  resp <- httr2::req_perform(req)
  httr2::resp_check_status(resp)
  
  # ¡OJO!: no simplificar para que no se “aplane” la lista
  cont <- httr2::resp_body_json(resp, simplifyVector = FALSE, simplifyDataFrame = FALSE)
  
  # Manejar errores estructurados de OpenAI
  if (!is.null(cont$error)) {
    msg <- cont$error$message %||% "Unknown API error"
    cli::cli_abort("OpenAI API error: {msg}")
  }
  
  # Extraer texto de manera segura
  out <- ""
  if (!is.null(cont$choices) && length(cont$choices) >= 1) {
    ch <- cont$choices[[1]]
    
    # Formato típico de chat.completions: choices[[1]]$message$content (string)
    if (!is.null(ch$message)) {
      msg <- ch$message
      # content puede ser string o lista (algunos backends devuelven lista de partes)
      if (is.list(msg) && !is.null(msg$content)) {
        if (is.character(msg$content)) {
          out <- msg$content
        } else if (is.list(msg$content)) {
          # concatena fragmentos si viniera como lista
          parts <- vapply(msg$content, function(p) {
            if (is.character(p)) return(p)
            if (is.list(p) && !is.null(p$text) && is.character(p$text)) return(p$text)
            ""
          }, character(1))
          out <- paste(parts, collapse = "")
        }
      } else if (is.character(msg)) {
        # Algunos clientes ponen directamente el texto aquí
        out <- msg
      }
    }
    
    # Fallback para modelos que devuelven 'text' en vez de 'message$content'
    if (!nzchar(out) && !is.null(ch$text) && is.character(ch$text)) {
      out <- ch$text
    }
  }
  
  if (!is.character(out)) out <- ""
  out
}

# helper: operador %||%
`%||%` <- function(a, b) if (is.null(a)) b else a
