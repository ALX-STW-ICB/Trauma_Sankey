# Trauma Sankey Explorer

A Shiny dashboard for exploring trauma patient flow data with interactive Sankey diagrams. The app is designed for healthcare analytics teams who need to understand how patients move through services, from admission to discharge outcomes. Users can interactively filter cohorts, expand key decision points, and surface critical drop-off pathways.

## Key Features
- **Interactive Sankey diagrams** that let users hover to inspect counts, click to expand or collapse nodes, and view the direction of patient flow through the care pathway.
- **Configurable cohort filters** for narrowing the analysis by demographics, facility, injury mechanism, or other metadata columns available in the provided CSV files.
- **Outcome insights** that highlight downstream services, disposition, and mortality so teams can target quality improvement efforts.
- **Built-in data dictionary** derived from the metadata CSV to help analysts understand each column’s meaning, units, and allowed values.

## Data Inputs
The application expects two CSV files in the project root:

| File | Purpose |
| --- | --- |
| `sankey_edges.csv` | Edge list defining the source and target nodes for the Sankey diagram along with patient counts. |
| `sankey_meta.csv` | Metadata describing nodes, labels, grouping colours, and any additional categorical filters exposed in the UI. |

You can replace these files with your own data as long as they respect the same schema. When adding new columns, update the `manifest.json` and any corresponding sections in `app.R` where the data is read and transformed.

## Running the App Locally
1. Install the R packages listed in `manifest.json` (the app relies primarily on `shiny`, `tidyverse`, and `networkD3`).
2. Open R in the project root.
3. Run the following command to launch the app:
   ```r
   shiny::runApp("app.R", launch.browser = TRUE)
   ```
4. Navigate to the displayed URL in your browser. The Sankey diagram will render automatically once the CSV data loads.

## Usage Tips
- Use the filter panel to focus on specific patient cohorts. Filters dynamically update the Sankey diagram so you can compare pathways across subgroups.
- Hover over links to reveal tooltips with patient counts and percentages relative to the selected cohort.
- Expand or collapse nodes to control the level of detail displayed. This is helpful for identifying where attrition occurs along the pathway.
- Download rendered charts or underlying data from the export controls for reporting.

## Customising the Experience
- **Adding new nodes or stages:** Update `sankey_edges.csv` with additional rows and ensure the corresponding node metadata exists in `sankey_meta.csv`.
- **Changing colours or labels:** Modify the `colour` and `label` columns in the metadata file; the UI will reflect these changes on the next run.
- **Extending filters:** Introduce new categorical columns in the metadata file and wire them into the Shiny UI components within `app.R`.

## Project Structure
```
.
├── app.R             # Main Shiny application script
├── manifest.json     # Package dependencies and configuration for deployment
├── sankey_edges.csv  # Edge definitions for the Sankey diagram
├── sankey_meta.csv   # Node metadata and filter definitions
└── README.md         # Project documentation (this file)
```

## Deployment
The app can be deployed to any Shiny hosting platform (e.g., [shinyapps.io](https://www.shinyapps.io) or RStudio Connect). Ensure the CSV files accompany the deployment bundle and that the required packages are installed on the target server.

## Getting Help
If you encounter issues, consider:
- Verifying the structure of the CSV inputs matches the expectations described above.
- Checking the R console for error messages when loading the app.
- Reviewing `app.R` to confirm that new data fields are properly referenced in the data preparation or UI code.

Contributions and suggestions are welcome via issues or pull requests.
