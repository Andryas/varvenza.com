---
title: Speending up your image with renv
author: Andryas Wavrzenczak
date: '2023-12-01'
slug: "docker-renv"
draft: false
series_order: 13
tags: [docker, r, renv]
---

To be completely transparent, my experience with renv only began last week. This
need arose as I've been juggling multiple Shiny applications, each bundled into
their own Docker image. In these images, I meticulously specify each package and
its version.

However, I've hit a snag: my Dockerfiles are growing increasingly unwieldy and
complex. That's when I decided to test the waters with renv.

My initial week with renv has been largely positive; it's user-friendly and
straightforward. But, integrating it into my Docker image building process has
been a bit of a challenge.

For those curious, this
[article](https://rstudio.github.io/renv/articles/docker.html) offers insights
into using Docker and renv together. It suggests three strategies, but none
perfectly matched my needs:

1. Install all the R packages every time the docker image is generated, which
   means a lot of time
2. Split your docker image in two parts, one to "freeze" the package
   installation, second for your code.
3. Share a volume of your cache to a run-time container.


However, I believe there's a 4th, more efficient approach:

4. Retrieve packages from the cache when available; otherwise, install them. This way, the lengthy installation process is only a one-time inconvenience.
   
In my quest for a solution, I stumbled upon a [stack
overflow](https://stackoverflow.com/questions/25305788/how-to-avoid-reinstalling-packages-when-building-docker-image-for-python-project)
discussion that addresses a similar issue for Python projects. It turns out that
the problem I'm facing with R is fundamentally the same.

Let's build a docker file caching the r packages.

First clone the following repository

{{< github repo="andryas/docker_renv" >}}

Second, you just need the `Dockerfile` and `build.sh`, all the other files were
there only for example.

Now, in your projet you can setting the renv as usual

```
renv::init()
renv::snapshot()
```

and if you want to build your docker image

```
build.sh
```

Done, it is ready to use and faster then furious. (rsrs)

# Screenshots

## Just setting the image with no package installed

```
bash build.sh
```

![](https://storage.googleapis.com/varvenza/docker-renv/1.png)


144 seconds, not bad.

## Installing dplyr

```
# uncomment the library R/dplyr.R
R -e "renv::snapshot()"
bash build.sh
```

![](https://storage.googleapis.com/varvenza/docker-renv/2.png)

you can see that everything before stage 11 was cached. And just to install
dplyr it took 663 seconds, good 10 minutes.

Now, if I just update the renv.lock with a new package? how long it is going to take?

## Installing dplyr + wesanderson

```
# uncomment the library R/wesanderson.R
R -e "renv::snapshot()"
bash build.sh
```

![](https://storage.googleapis.com/varvenza/docker-renv/3.png)

20 seconds!!!!!!!!

That's it.

![](https://storage.googleapis.com/varvenza/docker-renv/4.gif)

Cheers