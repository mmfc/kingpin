
#' Pin deactivate
#'
#' @description "Carefully" deactivates a pin by transferring its data to a temporary pin scheduled for deletion. The pin will be backed up for 7 working days by default.
#' @usage pin_deactivate(
#' board,
#' server,
#' key,
#' names)
#'
#' @param board A pins board object from board_rsconnect()
#' @param server URL of the board server. It's recommended to store these details in .Renviron and use Sys.getenv()
#' @param key API key to access the board. It's recommended to store these details in .Renviron and use Sys.getenv()
#' @param names Name of the pins to be deactivated. Can be a single value or a vector of pin names.
#'
#' @return Specified pin will be deleted but backed up in pin_pit
#' @export
#' @examples
#' # Basic usage, assuming .Renviron is set up with CONNECT_SERVER and CONNECT_API_SERVER environmental variables:
#' library(kingpin)
#' board <- kingpin::board_rsconnect(server = Sys.getenv("CONNECT_SERVER"), key = Sys.getenv("CONNECT_API_KEY"))
#'
#' # Pin something temporary first
#' kingpin::pin_throw(board, data.frame(a = 1:10, b = 1:10), "tempiris")
#'
#' # Retrieve pin
#' kingpin::pin_deactivate(board,
#' server = Sys.getenv("CONNECT_SERVER"),
#' key = Sys.getenv("CONNECT_API_KEY"),
#' names = "tempiris")
#'
#' # To check if the pin has been backed up in pin_pit:
#' pin_pit <- kingpin::pin_return(board, "pin_pit")
#'
pin_deactivate <- function(board,
                           server,
                           key,
                           names) {

  text <- "Deleted and backed up: \n"

  for (i in 1:length(names)) {

    # Clean pin name
    name <- sub('.*/', '', names[i])

    # Check if user has access to the pin
    content <- suppressMessages(purrr::safely(pins::pin_read)(board, name))
    if (is.null(content$result)) { stop("The pin doesn't exist or you don't have access to the pin. Please contact the pin owner for access.") }

    # RENAME PIN AND ADD DATA TO PIN_PIT
    backup_first <- purrr::quietly(pins::pin_read)(board, name)$result
    pin_pit <- purrr::quietly(pins::pin_read)(board, "pin_pit")$result

    pin_pit[[name]] <- list(content = backup_first,
                              countdown = "7 days to deletion")

    suppressMessages(pins::pin_write(board, pin_pit, "pin_pit"))

    # DELETION
    call_pins <- httr::GET(paste0(server, "__api__/v1/content"),
                           httr::add_headers(Authorization = paste("Key", key)))

    id <- dplyr::bind_rows(httr::content(call_pins))
    id <- id$guid[id$name == name] # ID of the pin to delete

    result <- httr::DELETE(paste0(server, "__api__/v1/content/", id),
                           httr::add_headers(Authorization = paste("Key", key)))

    text <- cat(text, paste0(name, " \U0002705", "\n"))

  }

}
