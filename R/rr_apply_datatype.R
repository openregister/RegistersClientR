#' Apply registers-style datatypes to fields
#'
#' @description
#' Registers use their own datatypes. This function converts character vectors
#'   to the equivalent R datatypes, handling cardinality='n'.
#'
#' @param x Character vector (a field of a register).
#' @param datatype Name of the datatype to apply: currently one of `"curie"`,
#'   `"url"`, `"datetime"`, `"string"`, `"integer"`, `"text"`, and `"point"`.
#'   Unrecognised datatypes will be returned as characters.
#' @param cardinality Character, one of `"1"` and `"n"` to say whether each
#'   element of `x` contains multiple values separated by semicolons.
#' @param apply_iso_8601 Logical, whether to parse ISO8601 strings as datetimes
#'   with [parsedate::parse_iso_8601()], otherwise leave as a string.  Partial
#'   datetimes are parsed as the earliest possible datetime, e.g. `"2018"`
#'   becomes `"2018-01-01 UTC"`.
#' @export
#' @examples
#' rr_apply_datatype("2014-04", "datetime")
rr_apply_datatype <- function(x, datatype, cardinality = 1, apply_iso_8601 = TRUE) {
  if (cardinality == "n") {
    out <- switch(datatype,
                  curie = purrr::map(x, as.character),
                  url = purrr::map(x, as.character),
                  datetime = purrr::map(x,
                                        maybe_parse_iso_8601,
                                        parse = apply_iso_8601),
                  string = purrr::map(x, as.character),
                  integer = purrr::map(x, as.integer),
                  point = purrr::map(x, as.character),
                  text = purrr::map(x, as.character),
                  purrr::map(x, as.character))
    return(out)
  }
  switch(datatype,
         curie = as.character(x),
         url = as.character(x),
         datetime = maybe_parse_iso_8601(x, apply_iso_8601),
         string = as.character(x),
         integer = as.integer(x),
         point = as.character(x),
         text = as.character(x),
         as.character(x))
}

#' Parse ISO8601 strings as datetimes or characters
#'
#' @param x Character vector
#' @param parse Logicial, whether to parse as a datetime or leave as (or convert
#' to) character [parsedate::parse_iso_8601()]
maybe_parse_iso_8601 <- function(x, parse = FALSE) {
  if (parse) {
    out <- purrr::map(x,
                      ~ if (is.na(.x)) {
                        as.POSIXct(NA)
                      } else {
                        parsedate::parse_iso_8601(.x)
                      })
    out <- do.call(c, out)
    return(out)
  }
  as.character(x)
}
