
#' Setup kingpin file to board
#'
#' @description Sets up an empty "kingpin" pin to a board to be populated by activity data
#' @usage setup_kingpin(
#' server,
#' key,
#' force = FALSE,
#' group = "Epi")
#'
#' @param server URL of the board server. It's recommended to store these details in .Renviron and use Sys.getenv()
#' @param key API key to access the board. It's recommended to store these details in .Renviron and use Sys.getenv()
#' @param force Whether to force an override of an existing kingpin.
#' @param group The group name to give editing permissions to by default
#'
#' @return A new pin named "kingpin" will be pinned on the board supplied to the function.
#' @export
#' @examples
#' # Basic usage, assuming .Renviron is set up with CONNECT_SERVER and CONNECT_API_SERVER environmental variables:
#' library(kingpin)
#' kingpin::setup_kingpin(server = Sys.getenv("CONNECT_SERVER"), key = Sys.getenv("CONNECT_API_KEY"))
#'
setup_kingpin <- function(server,
                          key,
                          force = FALSE,
                          group = "Epi") {

  board <- pins::board_connect(server = server,
                                 key = key)

  kingpin <- list(
    records = data.frame(pin_name = "kingpin", # pin name
                         project_name = "none", # name of project associated with pin, if applicable
                         writer = Sys.info()["user"], # username of pin_write instance
                         write_date = Sys.time(), # date of pin_write instance
                         reader = NA, # username of pin_read instance
                         read_date = NA, # date of pin_read instance
                         last_modified = NA,
                         comment = "Kingpin holding pin usage data")
    )


  pin_pit <- list()

  # ERROR HANDLING
  prev_data <- purrr::quietly(try)( # catch error if it happens. class will be try-error if it does.
    pins::pin_read(board, "kingpin"), silent = T)$result

  if(class(prev_data) != "try-error" & !force) {

    message("Kingpin already exists in RSConnect Board. Either manually remove, or use force = TRUE.")

  } else {

    # PIN KINGPIN
    res <- purrr::quietly(pins::pin_write)(board, kingpin, "kingpin")
    message("Kingpin on board.")

    res <- purrr::quietly(pins::pin_write)(board, pin_pit, "pin_pit")
    message("Pin pit made.")

    # ADJUST PERMISSIONS
    call_group <- httr::GET(paste0(server, "__api__/v1/groups"),
                            httr::add_headers(Authorization = paste("Key", key)))

    guid <- dplyr::bind_rows(httr::content(call_group)$results) |>
      dplyr::filter(name == group) |>
      dplyr::pull(guid)

    call_pins <- httr::GET(paste0(server, "__api__/v1/content"),
                           httr::add_headers(Authorization = paste("Key", key)))

    ids <- dplyr::bind_rows(httr::content(call_pins)) |>
      dplyr::filter(name %in% c("kingpin", "pin_pit")) |>
      dplyr::pull(guid)

    body <- paste0('{
    "principal_guid": "', guid, '",
    "principal_type": "group",
    "role": "owner"
    }')

    result <- httr::POST(paste0(server, "__api__/v1/content/", ids[1], "/permissions"),
                         body = body, encode = "raw",
                         httr::add_headers(Authorization = paste("Key", key)))

    result <- httr::POST(paste0(server, "__api__/v1/content/", ids[2], "/permissions"),
                         body = body, encode = "raw",
                         httr::add_headers(Authorization = paste("Key", key)))

    message(paste0("Owner permissions given to group ", group))

  }

}
