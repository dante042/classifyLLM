

# classifyLLM <a href="https://dante042.github.io/classifyLLM"><img src="https://img.shields.io/badge/docs-pkgdown-blue" align="right" height="24"></a>
<img src="/logo.png" align="right" height="300" />

**classifyLLM** brings the power of modern large language models (LLMs) directly into tidyverse data pipelines.It offers a simple, transparent, and auditable way to classify text into predefined categories—without the need to train or maintain your own machine-learning models.

By combining R’s native data-wrangling syntax with LLM-based reasoning, classifyLLM allows analysts to apply consistent classification logic across large datasets using a single line of code inside `mutate()`.
The package handles prompt construction, model communication, and output parsing automatically, returning results as tidy columns that integrate seamlessly with existing workflows.

This makes **classifyLLM** particularly useful for text-rich humanitarian, social science, or policy datasets—where labels or categories are often context-specific and traditional supervised models are difficult to build due to limited training data or changing definitions.

------------------------------------------------------------------------

## 🧭 Why this package

Analysts and researchers often need to classify open-ended text
fields: - survey responses or interview transcripts  
- “other” categories in datasets  
- qualitative notes from reports  
- lists of job titles, symptoms, or objects

Traditional NLP workflows require model training, feature engineering,
or external tools.  
`classifyLLM` lets you use an LLM (e.g. GPT-4) to perform classification
directly, within your data pipeline.

------------------------------------------------------------------------

## 🚀 Features

| Feature | Description |
|----|----|
| 🧹 **Tidyverse integration** | Works naturally inside `mutate()`, `across()`, or `map()` pipelines. |
| ⚙️ **Deterministic and auditable** | Set temperature = 0 for reproducible results. |
| 📦 **Batching and rate control** | `batch_size` and `delay` prevent rate-limit errors. |
| 🔐 **Secure key management** | Use `set_openai_key()` or environment variable `OPENAI_API_KEY`. |
| 🧪 **Testing support** | API calls skipped if key not set; mock mode planned for CI. |
| 💬 **Fallback logic** | Normalizes and corrects near matches, prevents blank outputs. |

------------------------------------------------------------------------

# 📦 Installation

You can install the development version of **classifyLLM** from GitHub using **{remotes}**:

```r
# install remotes if needed
install.packages("remotes")

# install classifyLLM from GitHub
remotes::install_github("dante042/classifyLLM")

# load the package
library(classifyLLM)
```

Before using the package, make sure your OpenAI API key is available as an environment variable:

```r
Sys.setenv(OPENAI_API_KEY = "your_api_key_here")
```

Or store it permanently in your `.Renviron` file:

```r
usethis::edit_r_environ()
# then add: OPENAI_API_KEY=your_api_key_here
```
------------------------------------------------------------------------
## 🧩 Example

``` r
library(classifyLLM)
library(dplyr)

Sys.setenv(OPENAI_API_KEY = "sk-...")   # or classifyLLM::set_openai_key()

tibble::tibble(animal = c("siamese kitty", "golden retriever", "parakeet")) |>
  mutate(species = classify_llm(
    animal,
    categories = c("cat", "dog", "bird"),
    model = "gpt-4o-mini",
    temperature = 0
  ))
```

## 🧠 New: Classify using a data frame of categories

While `classify_llm()` lets you define categories directly in the
function call, the new `classify_df()` function lets you provide a tidy
data frame of categories and optional descriptions, perfect when your
taxonomy is stored in a CSV or shared file.

``` r
library(classifyLLM)
library(dplyr)

# Example texts
texts <- tibble::tibble(
  id = 1:3,
  content = c(
    "Food distribution in border camp delayed by insecurity.",
    "Price inflation accelerates in host communities.",
    "Asylum application processing times decrease."
  )
)


# Category definitions

categories <- tibble::tribble(
  ~category,       ~description,
  "Protection",    "Risks, incidents, access to territory/asylum, GBV/CP",
  "Basic Needs",   "Shelter, food, WASH, core relief items",
  "Livelihoods",   "Jobs, income, markets, prices",
  "Procedures",    "RSD, documentation, processing, status"
)

# Classify with a tidy category table
texts |> 
  classify_df(content, categories = categories, model = "gpt-4o-mini")

#> # A tibble: 3 × 4
#>      id content                                         .pred_category .pred_score
#>   <int> <chr>                                           <chr>                <dbl>
#> 1     1 Food distribution in border camp delayed by ... Basic Needs          0.87
#> 2     2 Price inflation accelerates in host communit... Livelihoods          0.91
#> 3     3 Asylum application processing times decrease.   Procedures           0.93
```
