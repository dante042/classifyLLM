
# classifyLLM <img src="/logo.png" align="right" height="140" />

# classifyLLM <a href="https://dante042.github.io/classifyLLM"><img src="https://img.shields.io/badge/docs-pkgdown-blue" align="right" height="24"></a>

**classifyLLM** brings the power of modern large language models (LLMs)
to tidyverse data pipelines.

It provides a minimal and transparent interface for classifying text
data into predefined categories directly from R—without building your
own machine-learning models.

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
