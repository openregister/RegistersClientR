#' Download a register
#'
#' @description Downloads a whole register and constructs an object that can be
#'   interrogated for its records, entries, items, schema, links to other
#'   registers, etc.
#'
#'   You should probably run [rr_snapshot()] on the output before using it.
#'
#' @param register character, name of the register, e.g. "school-eng"
#' @param phase character, one of "beta", "alpha", default: "beta"
#'
#' @return An S3 object of class `register`
#'
#' @examples
#' \dontrun{
#'   rr_register("country")
#'   rr_register("country", "beta")
#' }
#'
#'
#' @export
rr_register <- function(register, phase = "beta") {
  register_url <-
    dplyr::if_else(phase == "beta",
            "https://{register}.register.gov.uk/download-rsf",
            "https://{register}.{phase}.openregister.org/download-rsf") %>%
    glue::glue()
  message("Downloading register '", register,
          "' from the '", phase, "' phase ...\n")
  # register_path <- tempfile()
  # on.exit(unlink(register_path))
  # download.file(register_url, register_path)
  register_path <- "./temp.rsf"
  rsf <- readr::read_lines(register_path)
  root_hash <- parse_root_hash(rsf)
  entries <- parse_entries(rsf)
  items <- parse_items(rsf)
  entry_data <- resolve_entry_items(entries, items)
  system_entries <- dplyr::filter(entry_data, type == "system")
  names <-
    dplyr::filter(system_entries, key == "name") %>%
    dplyr::select(-json) %>%
    unnest()
  custodians <-
    dplyr::filter(system_entries, key == "custodian") %>%
    dplyr::select(-json) %>%
    unnest()
  fields <-
    dplyr::filter(system_entries, stringr::str_detect(key, "^field:")) %>%
    dplyr::select(-json) %>%
    unnest()
  user_entries <-
    dplyr::filter(entry_data, type == "user") %>%
    dplyr::select(-json) %>%
    unnest() %>%
    dplyr::select(`entry-number`, type, key, timestamp, hash,
                  unique(fields$field))
  structure(list(root_hash = root_hash,
                 entries = entries,
                 items = items,
                 schema = list(names = names,
                               custodians = custodians,
                               fields = fields),
                 data = list(entries = user_entries)),
            class = "register")
}

parse_root_hash <- function(rsf) {
  root_hash_line <- rsf[stringr::str_detect(rsf, "^assert-root-hash\\t")]
  stringr::str_extract(root_hash_line, "(?<=^assert-root-hash\\t).*$")
}

parse_entries <- function(rsf) {
  rsf[stringr::str_detect(rsf, "^append-entry\\t")] %>%
    paste0(collapse = "\n") %>%
    paste0("\n") %>%
    readr::read_tsv(col_types = c("_ccTc"),
                    col_names = c("type", "key", "timestamp", "hash-list"),
                    na = character()) %>%
    dplyr::mutate(`hash-list` = purrr::map(`hash-list`, parse_hash_list),
                  `entry-number` = seq_len(n())) %>%
    dplyr::select(`entry-number`, dplyr::everything())
}

parse_items <- function(rsf) {
  rsf[stringr::str_detect(rsf, "^add-item\\t")] %>%
    stringr::str_extract("(?<=^add-item\\t).*$") %>%
    tibble::tibble(json = .) %>%
    dplyr::mutate(hash = purrr::map_chr(json,
                                        digest::digest,
                                        algo = "sha256",
                                        serialize = FALSE),
                  json = purrr::map(json, jsonlite::fromJSON),
                  data = purrr::map(json, as_tibble))
}

parse_hash_list <- function(x) {
  stringr::str_extract(stringr::str_split(x, ";")[[1]], "(?<=^sha-256:).*$")
}

resolve_entry_items <- function(entries, items) {
  entries %>%
    tidyr::unnest(`hash-list`) %>%
    dplyr::rename(hash = `hash-list`) %>%
    dplyr::left_join(items, by = "hash")
}