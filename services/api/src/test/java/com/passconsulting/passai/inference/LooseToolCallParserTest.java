package com.passconsulting.passai.inference;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

import java.util.List;

import org.junit.jupiter.api.Test;

import com.fasterxml.jackson.databind.ObjectMapper;

class LooseToolCallParserTest {

	private final ObjectMapper mapper = new ObjectMapper();

	@Test
	void parsesToolsBlock() throws Exception {
		String content = "<tools>\n{\"name\": \"editor\", \"arguments\": {\"path\": \"a.html\", \"new_text\": \"hi\"}}\n</tools>";
		List<LooseToolCallParser.ParsedToolCall> calls = LooseToolCallParser.parse(content, mapper);
		assertEquals(1, calls.size());
		assertEquals("editor", calls.get(0).name());
	}

	@Test
	void parsesChatMlPrefix() throws Exception {
		String content = "<|im_start|> {\"name\": \"editor\", \"arguments\": {\"path\": \"cofee.html\", \"new_text\": \"<p>hi</p>\"}}";
		List<LooseToolCallParser.ParsedToolCall> calls = LooseToolCallParser.parse(content, mapper);
		assertEquals(1, calls.size());
		assertEquals("editor", calls.get(0).name());
	}

	@Test
	void skipsPlainProseWithoutTools() {
		assertEquals(0, LooseToolCallParser.parse("I'll create a file next.", mapper).size());
	}
}
