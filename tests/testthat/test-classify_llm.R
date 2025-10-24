test_that("classify_llm returns factor of correct length", {
  skip_if_not(nzchar(Sys.getenv("OPENAI_API_KEY")), "No API key set")
  x <- c("siamese kitty","golden retriever","parakeet")
  cats <- c("cat","dog","bird")
  out <- classify_llm(x, cats, model = "gpt-4o-mini", temperature = 0)
  expect_s3_class(out, "factor")
  expect_length(out, length(x))
  expect_setequal(levels(out), cats)
})
