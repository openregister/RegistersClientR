#' Download a register RSF file
#'
#' @description
#' Either downloads the Register Serialisation Format (RSF) file of a register,
#'   constructing the URL from the name of the register and the given phase, or
#'   reads it from disk.  Optionally saves it to disk.
#'
#' @param name Character, the name of the register.
#' @param phase Character, one of `"beta"`, `"alpha"`, and `"discovery"`
#' @param file Character, file path or URL, passed on to [readr::read_lines()]
#'   if `name` is not provided.
#' @param write Logical, whether to write the RSF file to disk.  If `TRUE`,
#'   either `name` or `dest_path` must be provided.
#' @param dest_path Character, path and file name to write the RSF to.
#' @param quiet Logical, if `TRUE` does not print messages to the console.
#' @param api_key Character, your API key.
#'
#' @export
#' @examples
#' rr_rsf("country")
rr_rsf <- function(name = NULL, phase = c("beta", "alpha", "discovery"),
                   file = NULL, write = FALSE, dest_path = NULL,
                   quiet = FALSE, api_key = "") {
  phase <- match.arg(phase)
  if (write) {
    if (is.null(dest_path)) {
      if (is.null(name)) {
        stop("`write` is TRUE but neither `name` nor `dest_path` has been provided.")
      }
      dest_dir <- phase
      dest_path <- fs::path(dest_dir, paste0(name, ".rsf"))
    }
  }
  if (is.null(name)) {
    out <- readr::read_lines(file)
  } else {
    register_url <-
      switch(phase,
             beta = "https://{name}.register.gov.uk/download-rsf",
             alpha = "https://{name}.{phase}.openregister.org/download-rsf",
             discovery = "https://{name}.cloudapps.digital/download-rsf")
    register_url <- glue::glue(register_url)
    if (!quiet) {
      message("Downloading register '", name,
              "' from the '", phase, "' phase ...\n")
    }
    register_path <- tempfile()
    handle <- curl::new_handle(useragent = "https://github.com/nacnudus/registr")
    on.exit(unlink(register_path))
    download <-
      tryCatch({curl::curl_download(register_url,
                            register_path,
                            quiet = quiet,
                            handle = handle)},
               error = function(e) {
                 simpleWarning(glue::glue("The register {name} could not be downloaded"))
                 return(NULL)
               })
    if (is.null(download)) return(NULL)
    out <- readr::read_lines(register_path)
  }
  if (write) {
    fs::dir_create(fs::path_dir(dest_path))
    readr::write_lines(out, dest_path)
  }
  return(out)
}
