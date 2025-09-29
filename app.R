# ───────────────────────────────────────────────────────────────
# SUS 110 Admissions – 8-stage Sankey (reads aggregated edges)
# Default view: stages 1–3 only; Stage 2 preselected to 'ECD or dental...'
# ───────────────────────────────────────────────────────────────
suppressPackageStartupMessages({
  library(shiny); library(dplyr); library(tidyr); library(stringr)
  library(networkD3); library(htmlwidgets); library(readr); library(purrr)
})

# New (portable)
EDGES_CSV <- "sankey_edges.csv"
META_CSV  <- "sankey_meta.csv"

edges_all <- readr::read_csv(EDGES_CSV, show_col_types = FALSE)
meta <- tryCatch(readr::read_csv(META_CSV, show_col_types = FALSE), error = function(e) NULL)

# Stage labels (CareHomeStatus last)
stage_labels <- c(
  "1"="ProviderSiteCode",
  "2"="AdmissionMethod",
  "3"="PrimaryDiagnosis",
  "4"="SecondaryDiagnosis01",
  "5"="HRG4 (with code)",
  "6"="DischargeDestination",
  "7"="DischargeMethod",
  "8"="PatientCareHomeStatus"
)

date_lbl <- if (!is.null(meta) && "date_range" %in% meta$key) {
  meta$value[match("date_range", meta$key)]
} else "date range unavailable"

stage_values <- function(edges, stg) {
  c(
    edges %>% dplyr::filter(src_stage == stg) %>% dplyr::pull(src),
    edges %>% dplyr::filter(dst_stage == stg) %>% dplyr::pull(dst)
  ) |> unique() |> sort()
}

# --- Defaults computed from data ----------------------------------------------
S1_CHOICES <- stage_values(edges_all, 1)
S2_CHOICES <- stage_values(edges_all, 2)

# <<< Preselect only Stage-2 values beginning with 'ECD or dental'
S2_DEFAULT <- S2_CHOICES[grepl("^ECD or dental", S2_CHOICES, ignore.case = TRUE)]
if (length(S2_DEFAULT) == 0) {
  # Fallback: keep first value so UI isn't empty if text differs slightly
  S2_DEFAULT <- head(S2_CHOICES, 1)
}

# <<< By default, include only stages 1–3
INCLUDE_DEFAULT <- as.character(1:3)

# ------------------------------------------------------------------------------
ui <- fluidPage(
  tags$head(tags$style(HTML("
    .title { font-size: 22px; font-weight: 700; margin-top: 10px; }
    .subtitle { font-size: 14px; color: #666; margin-bottom: 10px; }
    .well { padding: 10px 12px; }
  "))),
  div(class = "title", "SUS 110 Admissions – 8-stage Sankey"),
  div(class = "subtitle", paste0("Data range: ", date_lbl, " | Stages: ",
                                 paste(stage_labels, collapse = " → "))),
  
  fluidRow(
    column(
      width = 3,
      div(class = "well",
          selectInput(
            "filter_s1", paste0("Stage 1: ", stage_labels["1"]),
            choices = S1_CHOICES,
            selected = S1_CHOICES,               # keep all S1 by default
            multiple = TRUE, selectize = TRUE
          ),
          selectInput(
            "filter_s2", paste0("Stage 2: ", stage_labels["2"]),
            choices = S2_CHOICES,
            selected = S2_DEFAULT,               # <<< only 'ECD or dental...' initially
            multiple = TRUE, selectize = TRUE
          ),
          checkboxInput("hide_other",   "Hide 'Other' nodes",   TRUE),
          checkboxInput("hide_unknown", "Hide 'Unknown' nodes", TRUE),
          
          # <<< Only 1–3 ticked initially; user can add 4–8 later
          checkboxGroupInput(
            "include_stages", "Include stages (add more to expand)",
            choices = setNames(as.character(1:8), stage_labels),
            selected = INCLUDE_DEFAULT
          ),
          
          checkboxInput("show_pct_of_stage", "Tooltip shows % of source-stage total", TRUE)
      )
    ),
    column(
      width = 9,
      sankeyNetworkOutput("sankey", height = "780px")
    )
  )
)

server <- function(input, output, session){
  
  keep_label <- function(lbl, hide_other = TRUE, hide_unknown = TRUE) {
    lbl <- as.character(lbl)
    is_other   <- if (isTRUE(hide_other))   grepl("\\bother\\b",   lbl, ignore.case = TRUE) else FALSE
    is_unknown <- if (isTRUE(hide_unknown)) grepl("\\bunknown\\b", lbl, ignore.case = TRUE) else FALSE
    !(is_other | is_unknown)
  }
  
  edges_filt <- reactive({
    req(input$filter_s1, input$filter_s2, input$include_stages)
    e <- edges_all
    
    # Stage-1 constraint
    e <- e %>% filter(!(src_stage == 1 & !(src %in% input$filter_s1)))
    
    # Stage-2 constraint (both as source/target)
    e <- e %>% filter(
      !(src_stage == 2 & !(src %in% input$filter_s2)),
      !(dst_stage == 2 & !(dst %in% input$filter_s2))
    )
    
    # Hide Other/Unknown
    e <- e %>% filter(keep_label(src, input$hide_other, input$hide_unknown),
                      keep_label(dst, input$hide_other, input$hide_unknown))
    
    # Stage on/off (adjacent stages only)
    sel <- as.integer(input$include_stages)
    e <- e %>% filter(src_stage %in% sel, dst_stage %in% sel, dst_stage == src_stage + 1)
    
    validate(need(nrow(e) > 0, "No rows match the filters/stage selection."))
    e
  })
  
  build_sankey <- reactive({
    e <- edges_filt()
    e2 <- e %>%
      mutate(
        node_from = paste0(src_stage, "│", src),
        node_to   = paste0(dst_stage, "│", dst)
      )
    
    nodes <- data.frame(name = unique(c(e2$node_from, e2$node_to)))
    idmap <- setNames(seq_len(nrow(nodes)) - 1, nodes$name)
    
    links <- e2 %>%
      transmute(
        source = idmap[node_from],
        target = idmap[node_to],
        value  = value
      )
    list(nodes = nodes, links = links)
  })
  
  output$sankey <- renderSankeyNetwork({
    x <- build_sankey()
    sank <- sankeyNetwork(
      Links = x$links, Nodes = x$nodes,
      Source = "source", Target = "target", Value = "value", NodeID = "name",
      nodeWidth = 28, nodePadding = 12, fontSize = 12, sinksRight = FALSE
    )
    
    htmlwidgets::onRender(
      sank,
      sprintf('
      function(el, x) {
        var links = d3.select(el).selectAll(".link");
        var stageDenom = {};
        links.each(function(d){
          var s = d.source.name.split("│")[0];
          stageDenom[s] = (stageDenom[s]||0) + d.value;
        });
        links.select("title").remove();
        links.append("title").text(function(d){
          var s = d.source.name.split("│")[0],
              denom = stageDenom[s] || 1,
              showPct = %s;
          var pct = showPct ? (100 * d.value / denom) : NaN;
          return d.source.name.replace("│"," – ") + " → " +
                 d.target.name.replace("│"," – ") +
                 "\\n" + d.value + (showPct ? (" (" + pct.toFixed(1) + "%% of stage " + s + ")") : "");
        });
      }',
              ifelse(isTRUE(input$show_pct_of_stage), "true", "false")
      )
    )
  })
}

shinyApp(ui, server)


