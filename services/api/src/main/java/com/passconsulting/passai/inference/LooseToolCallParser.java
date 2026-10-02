package com.passconsulting.passai.inference;



import java.util.ArrayList;

import java.util.LinkedHashSet;

import java.util.List;

import java.util.Optional;

import java.util.Set;

import java.util.UUID;

import java.util.regex.Matcher;

import java.util.regex.Pattern;



import com.fasterxml.jackson.databind.JsonNode;

import com.fasterxml.jackson.databind.ObjectMapper;

import com.fasterxml.jackson.databind.node.ObjectNode;



/**

 * Parses tool calls that models emit as plain text when SGLang does not promote them to OpenAI

 * {@code tool_calls} (e.g. Qwen2.5 {@code <tools>} blocks, Qwen3 ChatML {@code <|im_start|>} leaks).

 */

final class LooseToolCallParser {



	private static final Pattern TOOLS_BLOCK = Pattern.compile("<tools>\\s*(.*?)\\s*</tools>", Pattern.DOTALL);

	private static final Pattern CHATML_TOKEN = Pattern.compile("<\\|im_(?:start|end)\\|>", Pattern.CASE_INSENSITIVE);

	private static final Pattern NAME_KEY = Pattern.compile("\\{\\s*\"name\"\\s*:");



	private LooseToolCallParser() {

	}



	record ParsedToolCall(String id, String name, String argumentsJson) {

	}



	static List<ParsedToolCall> parse(String content, ObjectMapper mapper) {

		if (content == null || content.isBlank()) {

			return List.of();

		}

		String normalized = CHATML_TOKEN.matcher(content).replaceAll("").trim();

		Set<String> seen = new LinkedHashSet<>();

		List<ParsedToolCall> out = new ArrayList<>();



		Matcher block = TOOLS_BLOCK.matcher(normalized);

		while (block.find()) {

			addParsed(extractJsonObject(block.group(1).trim(), mapper), out, seen);

		}

		if (!out.isEmpty()) {

			return out;

		}



		for (String candidate : findBalancedToolJsonCandidates(normalized)) {

			addParsed(extractJsonObject(candidate, mapper), out, seen);

		}

		if (!out.isEmpty()) {

			return out;

		}



		addParsed(extractJsonObject(normalized, mapper), out, seen);

		return out;

	}



	private static void addParsed(Optional<ParsedToolCall> parsed, List<ParsedToolCall> out, Set<String> seen) {

		parsed.ifPresent(call -> {

			String key = call.name() + "\0" + call.argumentsJson();

			if (seen.add(key)) {

				out.add(call);

			}

		});

	}



	private static List<String> findBalancedToolJsonCandidates(String text) {

		List<String> candidates = new ArrayList<>();

		Matcher m = NAME_KEY.matcher(text);

		while (m.find()) {

			int start = m.start();

			int end = indexOfBalancedObjectEnd(text, start);

			if (end > start) {

				candidates.add(text.substring(start, end + 1));

			}

		}

		return candidates;

	}



	private static int indexOfBalancedObjectEnd(String text, int start) {

		if (start >= text.length() || text.charAt(start) != '{') {

			return -1;

		}

		int depth = 0;

		boolean inString = false;

		boolean escape = false;

		for (int i = start; i < text.length(); i++) {

			char c = text.charAt(i);

			if (inString) {

				if (escape) {

					escape = false;

				}

				else if (c == '\\') {

					escape = true;

				}

				else if (c == '"') {

					inString = false;

				}

				continue;

			}

			if (c == '"') {

				inString = true;

				continue;

			}

			if (c == '{') {

				depth++;

			}

			else if (c == '}') {

				depth--;

				if (depth == 0) {

					return i;

				}

			}

		}

		return -1;

	}



	private static Optional<ParsedToolCall> extractJsonObject(String text, ObjectMapper mapper) {

		String trimmed = text.trim();

		if (!trimmed.startsWith("{")) {

			int idx = trimmed.indexOf("{\"name\"");

			if (idx < 0) {

				idx = trimmed.indexOf("{ \"name\"");

			}

			if (idx >= 0) {

				int end = indexOfBalancedObjectEnd(trimmed, idx);

				if (end > idx) {

					trimmed = trimmed.substring(idx, end + 1);

				}

			}

		}

		if (!trimmed.startsWith("{")) {

			return Optional.empty();

		}

		try {

			JsonNode node = mapper.readTree(trimmed);

			if (!node.has("name")) {

				return Optional.empty();

			}

			String name = node.path("name").asText(null);

			if (name == null || name.isBlank()) {

				return Optional.empty();

			}

			JsonNode argsNode = node.has("arguments") ? node.get("arguments") : node.get("parameters");

			if (argsNode == null || argsNode.isNull()) {

				return Optional.empty();

			}

			return Optional.of(new ParsedToolCall(newCallId(), name, mapper.writeValueAsString(argsNode)));

		}

		catch (Exception ex) {

			return extractEditorFallback(trimmed, mapper);

		}

	}



	/** When model emits invalid JSON inside {@code new_text}, still recover path + body for editor. */

	private static Optional<ParsedToolCall> extractEditorFallback(String text, ObjectMapper mapper) {

		if (!text.contains("\"editor\"") && !text.contains("\"name\": \"editor\"")) {

			return Optional.empty();

		}

		Pattern pathPat = Pattern.compile("\"path\"\\s*:\\s*\"((?:\\\\.|[^\"\\\\])*)\"", Pattern.DOTALL);

		Matcher pathM = pathPat.matcher(text);

		if (!pathM.find()) {

			return Optional.empty();

		}

		String path = unescapeJsonString(pathM.group(1));

		int newTextKey = text.indexOf("\"new_text\"");

		if (newTextKey < 0) {

			return Optional.empty();

		}

		int valueStart = text.indexOf('"', newTextKey + "\"new_text\"".length());

		if (valueStart < 0) {

			return Optional.empty();

		}

		valueStart++;

		StringBuilder body = new StringBuilder();

		for (int i = valueStart; i < text.length(); i++) {

			char c = text.charAt(i);

			if (c == '\\' && i + 1 < text.length()) {

				body.append(text.charAt(i + 1));

				i++;

				continue;

			}

			if (c == '"') {

				break;

			}

			body.append(c);

		}

		try {

			ObjectNode args = mapper.createObjectNode();

			args.put("path", path);

			args.put("new_text", body.toString());

			return Optional.of(new ParsedToolCall(newCallId(), "editor", mapper.writeValueAsString(args)));

		}

		catch (Exception ex) {

			return Optional.empty();

		}

	}



	private static String unescapeJsonString(String value) {

		return value.replace("\\\\", "\\").replace("\\\"", "\"").replace("\\n", "\n").replace("\\t", "\t");

	}



	private static String newCallId() {

		return "call_" + UUID.randomUUID().toString().replace("-", "").substring(0, 24);

	}

}


