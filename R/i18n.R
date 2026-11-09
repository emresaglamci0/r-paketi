# Bilingual message lookup. Texts live in inst/i18n/messages.csv (UTF-8).

resolve_lang <- function(lang = NULL) {
  lang <- lang %||% getOption("plansize.lang") %||% "en"
  if (!is.character(lang) || length(lang) != 1L || !lang %in% c("en", "tr")) {
    stop("Unsupported language: ", format(lang), ". Use \"en\" or \"tr\".", call. = FALSE)
  }
  lang
}

read_messages <- function() {
  path <- system.file("i18n", "messages.csv", package = "plansize")
  utils::read.csv(path, fileEncoding = "UTF-8", stringsAsFactors = FALSE,
                  na.strings = character())
}

msg <- function(key, ..., lang = NULL) {
  lang <- resolve_lang(lang)
  x <- read_messages()
  i <- match(key, x$key)
  if (is.na(i)) stop("Unknown message key: ", key, call. = FALSE)
  sprintf(x[[lang]][i], ...)
}

`%||%` <- function(a, b) if (is.null(a)) b else a
