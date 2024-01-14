---
title: Google Autocomplete Address in R Shiny
author: Andryas Wavrzenczak
date: '2022-05-05'
slug: "google-autocomplete-address-in-r-shiny"
draft: false
series_order: 13
tags: ["googlemaps", "shiny"]
---

{{< github repo="andryas/aw-shiny" >}}

![](app.gif)

A quick shiny tip here. 

Little context.

I've been working with real estate for a while now and I'm constantly needing to add search input for address in the applications. I got this awnser [here](https://stackoverflow.com/questions/53347495/r-shiny-map-search-input-box) 
some time ago which I changed in the code below, a shiny module.

You just need to add in your `.Renviron` your google map key to `GCP_TOKEN_MAPS`
or you can just pass the key to the function `googlemap_autocomplete_search_ui`
and `googlemap_autocomplete_search_server` and voila.

# The module

`googlemap_autocomplete_search.R`

```R
googlemap_autocomplete_search_ui <- function(
    id,
    label = "Type an address",
    width = NULL,
    placeholder = NULL,
    key = NULL,
    ...
    ) {
  if (is.null(key)) key <- Sys.getenv("GCP_TOKEN_MAPS")

  ns <- NS(id)
  button <- ns("button")
  jsValue <- ns("jsValue")
  jsValueAddressNumber <- ns("jsValueAddressNumber")
  jsValuePretty <- ns("jsValuePretty")
  jsValueCoords <- ns("jsValueCoords")
  script <- stringr::str_c("
    <script>
        function initAutocomplete() {

        var autocomplete =   new google.maps.places.Autocomplete(document.getElementById('${button}'),{types: ['geocode']});
        autocomplete.setFields(['address_components', 'formatted_address',  'geometry', 'icon', 'name']);
        autocomplete.addListener('place_changed', function() {
        var place = autocomplete.getPlace();
        if (!place.geometry) {
            return;
        }

        var addressPretty = place.formatted_address;
        var address = '';
        if (place.address_components) {
        address = [
        (place.address_components[0] && place.address_components[0].short_name || ''),
        (place.address_components[1] && place.address_components[1].short_name || ''),
        (place.address_components[2] && place.address_components[2].short_name || ''),
        (place.address_components[3] && place.address_components[3].short_name || ''),
        (place.address_components[4] && place.address_components[4].short_name || ''),
        (place.address_components[5] && place.address_components[5].short_name || ''),
        (place.address_components[6] && place.address_components[6].short_name || ''),
        (place.address_components[7] && place.address_components[7].short_name || '')
        ].join(' ');
        }
        var address_number =''
        address_number = [(place.address_components[0] && place.address_components[0].short_name || '')]
        var coords = place.geometry.location;
        //console.log(address);
        Shiny.onInputChange('${jsValue}', address);
        Shiny.onInputChange('${jsValueAddressNumber}', address_number);
        Shiny.onInputChange('${jsValuePretty}', addressPretty);
        Shiny.onInputChange('${jsValueCoords}', coords);});}
    </script>
    <script src='https://maps.googleapis.com/maps/api/js?key=${key}&libraries=places&callback=initAutocomplete' async defer></script>"
  )

  shiny::tagList(
    htmltools::div(
      id = stringr::str_c(button, "-layout"),
      shiny::textInput(
        inputId = button,
        label = label,
        width = width,
        placeholder = placeholder
      ),
      htmltools::HTML(stringr::str_interp(script)),
      ...
    )
  )
}

googlemap_autocomplete_search_server <- function(id, key = NULL) {
  if (is.null(key)) key <- Sys.getenv("GCP_TOKEN_MAPS")

  shiny::moduleServer(
    id,
    function(input, output, session) {
      my_address <- shiny::reactive({
        if (!is.null(input$jsValueAddressNumber)) {
          if (
            length(grep(input$jsValueAddressNumber, input$jsValuePretty)) == 0
          ) {
            final_address <- c(
              input$jsValueAddressNumber, 
              input$jsValuePretty
            )
          } else {
            final_address <- input$jsValuePretty
          }
          return(final_address)
        }
      })

      address <- reactive({
        shiny::req(my_address())
        result <- googleway::google_geocode(my_address(), key = key)
        return(result)
      })

      address
    }
  )
}
```

# The App

`www/custom.css` 

```css
body {
    height: 100%;
    width: 100%;
}

.container-fluid {
    height: 100vh;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
}

.leaflet-container {
    border-radius: 15px;
    margin: 27px;
}

#teste-button-layout {
    width: 500px;
}
```

`app.R`

```R
library(shiny)
library(shinyjs)

source("googlemap_autocomplete_search.R")

ui <- fluidPage(
  useShinyjs(),

  includeCSS("www/custom.css"),

  googlemap_autocomplete_search_ui(
    "teste",
    width = "100%",
    key = Sys.getenv("GCP_TOKEN_MAPS")
  ),

  leaflet::leafletOutput("map", width = "auto", height = "auto")
)

server <- function(input, output, session) {
  address <- googlemap_autocomplete_search_server(
    "teste",
    key = Sys.getenv("GCP_TOKEN_MAPS")
  )

  output$map <- leaflet::renderLeaflet({
    shiny::req(address())

    shinyjs::runjs('$("#map").width(500).height(500);')

    leaflet::leaflet() |>
      leaflet::addTiles() |>
      leaflet::setView(
        lng = address()[["results"]][["geometry"]][["location"]][["lng"]],
        lat = address()[["results"]][["geometry"]][["location"]][["lat"]],
        zoom = 13
      ) |>
      leaflet::addMarkers(
        lng = address()[["results"]][["geometry"]][["location"]][["lng"]],
        lat = address()[["results"]][["geometry"]][["location"]][["lat"]],
        popup = "Well done, noble warrior!"
      )
  })
}

shinyApp(ui, server)
```

![](app.gif)


Cheers!