# classifyLLM <a href="https://dante042.github.io/classifyLLM"><img src="https://img.shields.io/badge/docs-pkgdown-blue" align="right" height="24"></a>

**classifyLLM** brings the power of modern large language models (LLMs) to tidyverse data pipelines.
# classifyLLM <img src="logo.png" align="right" height="120"/>

It provides a minimal and transparent interface for classifying text data into predefined categories directly from R—without building your own machine-learning models.

---

## 🧭 Why this package

Analysts and researchers often need to classify open-ended text fields:
- survey responses or interview transcripts  
- “other” categories in datasets  
- qualitative notes from reports  
- lists of job titles, symptoms, or objects  

Traditional NLP workflows require model training, feature engineering, or external tools.  
`classifyLLM` lets you use an LLM (e.g. GPT-4) to perform classification directly, within your data pipeline.

---

## 🚀 Features

| Feature | Description |
|----------|-------------|
| 🧹 **Tidyverse integration** | Works naturally inside `mutate()`, `across()`, or `map()` pipelines. |
| ⚙️ **Deterministic and auditable** | Set temperature = 0 for reproducible results. |
| 📦 **Batching and rate control** | `batch_size` and `delay` prevent rate-limit errors. |
| 🔐 **Secure key management** | Use `set_openai_key()` or environment variable `OPENAI_API_KEY`. |
| 🧪 **Testing support** | API calls skipped if key not set; mock mode planned for CI. |
| 💬 **Fallback logic** | Normalizes and corrects near matches, prevents blank outputs. |

---

## 🧩 Example

```r
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
