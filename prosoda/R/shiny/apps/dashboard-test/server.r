## This file is part of prosoda.  prosoda is free software: you can
## redistribute it and/or modify it under the terms of the GNU General Public
## License as published by the Free Software Foundation, version 2.
##
## This program is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
## FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
## details.
##
## You should have received a copy of the GNU General Public License
## along with this program; if not, write to the Free Software
## Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
##
## Copyright 2013 by Siemens AG, Wolfgang Mauerer <wolfgang.mauerer@siemens.com>
## All Rights Reserved.

##
## Software Project Dashboard-Test (server.r)
##

suppressPackageStartupMessages(library(RJSONIO))
suppressPackageStartupMessages(library(shinyGridster))

source('gridsterWidgetsExt.r', chdir=TRUE)
source("../common.server.r", chdir=TRUE)   # REMARK: only source and library statements used here !!!

## generate a unique name to be added to list
## template used is: "prefix<integer>"
getuniqueid <- function( x , prefix = "") {
  idrange <- length(x)+10
  newid <- paste(prefix,as.character(sample(1:idrange,1)),sep="")
  while ((newid %in% x)) {
    newid <- paste(prefix,as.character(sample(1:idrange,1)),sep="")
  }
  newid 
}

##
## Widget Builder for new widgets
##
widgetbase.output.new <- function(id, w, pid, selected.pids) {
  widgetbase.output(id,w,pid,w$size.x, w$size.y, 1, 1, selected.pids)
}

##
## Widget builder for fully configured widgets
##
widgetbase.output <- function(id, w, pid, size_x, size_y, col, row, selected.pids) {
  wb <- list()
  tryCatch({
    
    ##
    ## Widget creation and initialization (see: widget.r)
    ##
    inst <- initWidget(newWidget(w, pid, reactive({NULL}), selected.pids))
    loginfo(paste("Finished initialising new widget:", w$name))
    
    ## build the widget's property list
    wb$id <- id
    wb$widget <- inst
    wb$widget.class <- w
    wb$html <- w$html(id)
    wb$size_x <- size_x
    wb$size_y <- size_y
    wb$col <- col
    wb$row <- row
    
    ## Hilfetext
    wb$help <- list(title=widgetTitle(inst)(), content=widgetExplanation(inst)(), html=TRUE, trigger="click" )
    
  }, warning = function(warn) {
    logwarn(paste("widgetbase.output.new(id=", id, " w=<", w$name,">, pid=",isolate(pid()),":", toString(warn)))
    print(traceback(warn))
  }, error = function(err) {
    logerror(paste("widgetbase.output.new(id=", id, " w=<", w$name,">, pid=",isolate(pid()),":", toString(err)))
    print(traceback(err))
  }, {})
  wb
}  

##
## Filter Widget List (remove widgets that take too long to load)
##
widget.list.filtered <- widget.list[
  names(widget.list) != "widget.commit.structure.mds" &
    names(widget.list) != "widget.punchcard.ml"
  ]

##
## Function to send a widget (needs session environment)
##    (parameter w: as generated by widgetbase.output)
##
sendWidgetContent <- function(session, w) {
  basehtml <- function(x) {
    tags$li(
      style=paste("background-color:",widgetColor(w$widget)(),";box-shadow: 10px 10px 5px #CCC;", sep=""),
      tags$i( class="icon-remove-sign hidden", style="float:right"), 
      tags$div( qaclass=class(w$widget)[1], qaid=w$id ),
      x) }
  #print(as.character(basehtml(w$html)))   
  session$sendCustomMessage(
    type = "GridsterMessage",
    message = list(
      msgname = "addWidget",   			# Name of message to send
      html = as.character(basehtml(w$html)),		# this is the html for the widget
      size_x = as.character(w$size_x),	# in units of grid width
      size_y = as.character(w$size_y),	# dto
      col = as.character(w$col),			# column in grid
      row = as.character(w$row),			# row in grid
      qaid = w$id,
      help = w$help
    )
  )}

##
## Function to configure the button menue (needs session environment)
##
sendGridsterButtonOptions <- function(session, options=list()) {
  session$sendCustomMessage(
    type = "GridsterMessage",
    message = list(
      msgname = "options",     		# Name of message to send
      options = options
      )
  )}

##
## The Server function
##
shinyServer(function(input, output, session) {
  
  ## log the Url parameters
  loginfo(isolate(names(session$clientData$url_search)))
  
  ##
  ## Callback when client terminates session
  ##
  session$onSessionEnded(function() {
    print("Session ended.")
    #if (dbDisconnect(conf$con)) cat("Database connection closed.")
  })

  ##
  ## Initialze lists
  ##
  widget.config <- list()
  widgets.for.rendering <- list() #all generated widgets created

  ##
  ## Url parameter String and Parameter List (reactive statements)
  ##    (Parameter string gets checked, see: nav/breadcrumb.shiny.r)
  ##
  paramstr <- reactive({urlparameter.checked(session$clientData$url_search)})
  paramlist <- reactive({urlparameter.as.list(paramstr())})
  
  ##
  ## Project id (reactive statement)
  ##
  pid <- reactive({
    pid <- paramlist()$projectid
    pid
  })

  ##
  ## Topic variable (reactive statement)
  ##
  topic <- reactive({t <- paramlist()$topic; if(is.null(t)) "overview" else t })

  ##
  ## Config file name variable (reactive statement)
  ##
  config.file <- reactive({paste("widget",topic(),"config",sep=".")})

  ##
  ## Render the breadcrumb (reactice output assignment)
  ##
  output$quantarchBreadcrumb <- renderUI({
    if (is.null(pid())) {
      renderBreadcrumbPanel("projects",paramstr())
      } else if (topic() == "overview") {
        renderBreadcrumbPanel("dashboard",paramstr())
        } else {
          renderBreadcrumbPanel("dashboard2",paramstr())
          }
    })


################## copied from server.r in cookies-demo  
  
  
  ##
  ## Returns the choices parameter for selectInput as a named vector
  ##
  choices <- projects.choices(projects.list)
  
  ##
  ## Returns a list of selected project names (reactive statement)
  ##
  selected <- reactive({ projects.selected( projects.list, input$qacompareids) })
  selected.pids <- reactive({  unlist(strsplit(input$qacompareids,",")) })
  
  ##
  ## Outputs an enhanced selectInput "selectedpids" (reactive assignment)
  ##    (uses the chosen.jquery.js plugin)
  ##
  output$selectpidsui <- renderCompareWithProjectsInput(
    "selectedpids","",choices, selected(), list(width="85%"))
  
  ##
  ## Update the "qacompareids" cookie with input from the "selectedpids" selectInput
  ##    (but beware of duplicate project names)
  ## 
  observe({
    dat <- input$selectedpids
    dat <- if(is.null(dat)) { list() } else { dat }
    ## TODO: pathLevel=1 does not seem to work
    updateCookieInput(session, "qacompareids", dat, pathLevel=0, expiresInDays=1)
  })
  
################# end copy  
  
  ##
  ## Observe context executed once on session start
  ##
  observe({
   
    #print(pid)
    loginfo(paste("Current PID =",pid()))
    
    ##  
    ## Get the widget.config from a configuration file  (TODO: select secure path)
    ##  
    if (is.null(pid())) {   

      ##
      ## Create a volatile configuration  (not stored) if no projectid was found in Url
      ##
      cls <- "widget.overview.project"
      if(!is.null(paramlist()$widget)) {
        cls <- paramlist()$widget
      }
      widget.config <- list(
        widgets=lapply(projects.list$id, function(pid) {
          w <- list(col = 1, row = 1,
               size_x = 1, size_y = 1,
               id = paste("widget",pid,sep=""),
               cls = cls,
               pid = pid)
          #force(w)
          #str(w)
          w
        })
      )
    } else if (topic() == "testall") {
      widget.config <- list(
        widgets=lapply(1:length(widget.list), function(i) {
          cls <- widget.list[[i]]
          w <- list(col = 1, row = 1,
               size_x = cls$size.x, size_y = cls$size.y,
               id = paste("widget", i, sep=""),
               cls = cls$widget.classes[[1]],
               pid = pid)
          w
        })
      )
    } else {
      
      ##
      ## Read from config file belonging to current topic (Url parameter)
      ##
      loginfo(paste("Try to read config file", config.file())) 
      widget.config <- dget(config.file()) 
      if (is.null(widget.config)) {
        widget.config <- list(widgets=list(), content=list())
      }
    }
    
    ##
    ## Send all widgets found in widget.config to the client
    ##
    for ( w in widget.config$widgets ) {
      
      ## workaround for NULL pids
      if (is.null(pid())) {
        this.pid <- reactive({w$pid})
        ## This evaluation is necessary, since otherwise
        ## w changes in the for loop and all have the same pid!
        force(this.pid())
      } else {
        this.pid <- pid
      }
      
      #loginfo(paste("Creating widget from config: ", w$id, "for classname: ", w$cls ))
      
      ##
      ## Build widget using the widgetbase.output builder
      ##
      loginfo(paste("Creating widget from config: ", w$id, "for classname: ", w$cls ))
      widget.classname <- as.character(w$cls)       
      widget.class <- widget.list[[widget.classname]]
      widgetbase <- widgetbase.output(w$id, widget.class, this.pid, w$size_x, w$size_y, w$col, w$row, selected.pids)
      
      #loginfo(paste("Preparing widget: ", w$id, "for class: ", widget.classname ))
      
      ##
      ## Push the new widget on rendering list 
      ##
      widgets.for.rendering[[w$id]] <<- widgetbase
      
      ##
      ## Send a custom message to Shiny client for adding the base widget
      ##
      sendWidgetContent(session, widgetbase)
      #print(widgets.for.rendering)
      
      } # end for

    ##
    ## Render the "Add Widget" dialog (disabled for pid==NULL)
    ##
    sendGridsterButtonOptions(session, options=list(addwidget=!is.null(pid())))
    if (!is.null(pid())) {
      topical.widgets <- sapply(widget.list, function(x) {
                                is.null(x$topics) || topic() %in% x$topics })
      widget.titles <- vapply(widget.list[topical.widgets], FUN=function(x){
                              x$name},FUN.VALUE=character(1))
      widget.select.list <- names(widget.titles)
      names(widget.select.list) <- widget.titles
      #print(widget.titles)
      output$addWidgetDialog <- renderUI(
        selectInput("addwidget.class.name", "Select Widget content:", widget.select.list))
      }
  }) # end observe
  
  ##
  ## Observe the gridster action menu button (see also: nav/gidsterWidgetExt.js)
  ##    (context also triggered after adding a new widget by input$gridsterActionMenu)
  ##
  observe({
    
    ##
    ## Button input returns widget configuration as JSON
    ##
    cjson <- input$gridsterActionMenu    
    #loginfo(paste("Got input from button:",cjson))

    if (!is.null(cjson) && isValidJSON(cjson,TRUE)) {
      
      ##
      ## Create R list object (unnamed) from JSON
      ## The first element is either "save" or "update". If it is "save", the
      ## configuration should be saved to file, otherwise only the displayed
      ## widgets should be updated.
      ##
      button.info <- fromJSON(cjson)
      save.or.update <- button.info[[1]]
      widgets.displayed <- button.info[[2]]

      
      ##
      ## Create list of widget ids supposed to be rendered
      ##
      n1 <- vapply(widgets.displayed, FUN=function(x){x$id},FUN.VALUE=character(1))
      #print(n1)
      
      ##
      ## Get ids of widgets created previously for rendering  
      n2 <- names(widgets.for.rendering)
      #print(n2)
      
      ##
      ## Create logical index for sub-setting only widgets from config (widgets.displayed) 
      ##
      n3 <- n2[n2 %in% n1]
      #print(n3)
      loginfo(paste("Widgets to be rendered:", paste(n3,collapse=",")))
      
      ##
      ## Create reactive assignments for each renderWidget statement
      ##
      for (n in n3) {
        
        ## create a new local environment
        local({
          nlocal <- n # store the widget name in local environment
          #loginfo(paste("Creating output for widget: ",nlocal))
          
          tryCatch({
            wout <- widgets.for.rendering[[nlocal]]
            #views <- listViews(wout$widget)
            #print(wout$id)
            #print(wout$widget)
            output[[wout$id]] <- renderWidget(wout$widget)
            
            ## remove rendered widget from rendering list, so it wont be re-rendered
            widgets.for.rendering[[nlocal]] <<- NULL
            
            }, warning = function(wr) {
              logwarn(paste("While rendering widget", wout$widget.class$name, ":", toString(wr)))
              print(traceback(wr))
            }, error = function(e) {
              logerror(paste("While rendering widget", wout$widget.class$name, ":", toString(e)))
              print(traceback(e))
            }, {})
         
          }) # end local
        } # end for
      ##
      ## Save this configuration as a .config file
      if (save.or.update == "save" && (!is.null(pid()) || (topic() == "testall"))) {
        ## update configuration file
        ## TODO: move to extra observe block
        ## TODO: save as cookie
        widget.config$widgets <- widgets.displayed
        #widget.config$content <- widget.content
        dput(widget.config, file = config.file(),
              control = c("keepNA", "keepInteger", "showAttributes"))
        loginfo("Saved configuration file.")
      }
    } #end if

    ## debug output to screen
    #output$testid <- renderText(paste(cjson,toJSON(widget.content)))

    }) # end observe

  ##
  ## Observe the "Add Widget" dialog input
  ##
  observe({

    ## modal dialog Save button will trigger this context
    if (input$addWidgetButton == 0) return()
    ## modal dialog selectInput is isolated, so it will only buffer the data
    widget.classname <- isolate({input$addwidget.class.name})

    ## check for null and empty string, because initially this could be delivered
    if (!is.null(widget.classname) && length(widget.classname) > 0) {
      ## get a new widgetid
      #ids.rendered <- names(widgets.for.rendering)
      ids.displayed <- vapply(widget.config$widgets, FUN=function(x){x$id},FUN.VALUE=character(1))
      #currentids <- c(ids.rendered[!(ids.rendered %in% ids.displayed)], ids.displayed)
      #print(currentids)
      id <- getuniqueid(ids.displayed, prefix="widget")
      
      ## save widget class to widget id to class map
      #widget.content[[id]] <<- widget.classname
      ## not needed in future
    
      ## create the widget class
      widget.class <- widget.list[[widget.classname]]

      ## add html to widget instance which wraps into gridster item
      widgetbase <- widgetbase.output.new(id, widget.class, pid, selected.pids)

      loginfo(paste("Creating new widget: ", id, "for class: ", widget.classname ))

      ## finally send widget base to client
      sendWidgetContent(session, widgetbase)

      ## push widget instance to rendering list
      ## when a new widget has been added, the widget button input will trigger
      ## the addition of content
      widgets.for.rendering[[id]] <<- widgetbase
      } #end if

 }) #end observe

})
