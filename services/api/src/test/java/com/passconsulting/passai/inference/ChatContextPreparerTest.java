package com.passconsulting.passai.inference;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;

import org.junit.jupiter.api.Test;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.passconsulting.passai.config.PassAiProperties;

class ChatContextPreparerTest {

	private final ObjectMapper objectMapper = new ObjectMapper();

	@Test
	void trimsOldestNonSystemMessagesWhenOverBudget() throws Exception {
		ChatContextPreparer preparer = preparerWithContext(1000);
		String body = """
				{
				  "model": "Qwen/Qwen3-Coder-30B-A3B-Instruct",
				  "messages": [
				    {"role":"system","content":"sys"},
				    {"role":"user","content":"%s"},
				    {"role":"assistant","content":"ok"},
				    {"role":"user","content":"latest"}
				  ]
				}
				""".formatted("a".repeat(4000));

		ChatContextPreparer.PrepareResult result = preparer.prepare(body);
		assertTrue(result.trimmed());
		JsonNode messages = objectMapper.readTree(result.requestBody()).path("messages");
		assertEquals(3, messages.size());
		assertEquals("sys", messages.get(0).path("content").asText());
		assertEquals("latest", messages.get(2).path("content").asText());
	}

	@Test
	void failsWhenSingleTurnExceedsWindow() {
		ChatContextPreparer preparer = preparerWithContext(2000);
		String body = """
				{
				  "model": "Qwen/Qwen3-Coder-30B-A3B-Instruct",
				  "messages": [
				    {"role":"user","content":"%s"}
				  ]
				}
				""".formatted("x".repeat(20_000));

		assertThrows(ChatContextPreparer.ContextLimitExceededException.class, () -> preparer.prepare(body));
	}

	private ChatContextPreparer preparerWithContext(int contextLength) {
		ModelCatalogService catalog = new ModelCatalogService(objectMapper, properties(), null) {
			@Override
			public synchronized List<ModelCatalogService.CatalogModel> catalog() {
				return List.of(new ModelCatalogService.CatalogModel(
						"Qwen/Qwen3-Coder-30B-A3B-Instruct",
						"test",
						"",
						"agent",
						contextLength));
			}
		};
		return new ChatContextPreparer(catalog, properties(), objectMapper);
	}

	private static PassAiProperties properties() {
		return new PassAiProperties(
				new PassAiProperties.Db(false),
				new PassAiProperties.Security(""),
				new PassAiProperties.Inference(
						"http://127.0.0.1:30000/v1",
						"",
						"",
						java.time.Duration.ofSeconds(30),
						java.time.Duration.ofMinutes(10),
						"Qwen/Qwen3-Coder-30B-A3B-Instruct"));
	}
}
