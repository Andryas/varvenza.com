---
title: Persistent data storage with Shiny and MongoDB
author: Andryas Wavrzenczak
date: '2023-11-26'
slug: "persistent-data-storage-with-shiny-and-mongodb"
draft: false
series_order: 13
tags: ["storage", "r", "shiny", "mongodb"]
---

(Backgroud image in this post was generated by chatgpt4)


{{< github repo="andryas/persistent-data-storage-with-shiny-and-mongodb" >}}

Creating apps with persistent data storage becomes necessary as you grow as a shiny developer. Without further ado, I will show you a case study.

Imagine the following:

You are some kind of gym instructor, and one of our responsibilities is registering new gym clients and tracking their weights over time.

In this sense, we need to be able to select a client or create a new one and register their weight as we go.

Below the application

![](https://storage.googleapis.com/varvenza/persistent-data-storage-with-shiny-and-mongodb/screen-1.png)


We can add a new client

![](https://storage.googleapis.com/varvenza/persistent-data-storage-with-shiny-and-mongodb/screen-2.png)

It'll shows in the `selectInput` all the clients

![](https://storage.googleapis.com/varvenza/persistent-data-storage-with-shiny-and-mongodb/screen-3.png)

If we change the `gender` and the `age` of one of them, and add some weight data.

![](https://storage.googleapis.com/varvenza/persistent-data-storage-with-shiny-and-mongodb/screen-4.png)

Now if we change the `client` its update accordingly to their info 

![](https://storage.googleapis.com/varvenza/persistent-data-storage-with-shiny-and-mongodb/screen-5.png)

That's the application, pretty simple and straitght to the point.

Now, let's divine the logic which allows us to store this data in MongoDB.

First, you need to have a MongoDB. I recommend starting one using docker; see
my repository.

{{< github repo="Andryas/aw-localhost" >}}

After initialize a mongo database, download the repository of this post, go to
the file `server.R` and you'll find a piece of code like below.

The `input$read_client` contains the "oid" of the mongodb which allows us get
the data and update all the inputs according to the client information. In other
words this piece of code is what "restore the client session".

The `freezeReactiveValue` blocks every part where there is a `input$gender`, `input$age` or `historic_record()` to rerun.

```r
[...]
observe({
    req(input$read_client)

    client_info <- conn$iterate(
        query = stringr::str_interp(
            '{"_id": {"$oid": "${oid}"}}',
            list(oid = input$read_client)
        ),
        fields = '{}'
    )

    client_info <- client_info$one()

    shiny::freezeReactiveValue(input, "gender")
    updateSelectInput(
        session = session,
        input = "gender",
        selected = ifelse(
            is.null(client_info$gender), 
            "male", 
            client_info$gender
        )
    )

    shiny::freezeReactiveValue(input, "age")
    shinyWidgets::updateAutonumericInput(
        session = session,
        input = "age",
        value = ifelse(
            is.null(client_info$age), 
            0, 
            client_info$age
        )
    )
    historic <- dplyr::bind_rows(client_info$historic)
    if (nrow(historic) > 0) {
        historic_record(historic)
    } else {
        historic_record(NULL)
    }

    client_info(client_info)
})
[...]
```

and at the end of the code there is this piece of code, which the comment
suggest, save each input every time it changes in the database.

```r
# ! Persistent storage ----
observe({
    req(client_info())

    payload <- list(
        "gender" = input$gender,
        "age" = input$age,
        "historic" = historic_record()
    )

    conn$update(
        stringr::str_interp(
            '{"_id": {"$oid": "${id}"}}', 
            list(id = client_info()[["_id"]])
        ),
        jsonlite::toJSON(
            list("$set" = payload), 
            auto_unbox = TRUE
        )
    )
})
```


![](https://storage.googleapis.com/varvenza/persistent-data-storage-with-shiny-and-mongodb/screen-6.png)

Cheers