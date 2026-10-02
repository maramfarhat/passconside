package com.passconsulting.passai.api;

import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.passconsulting.passai.inference.InferenceProxyService;

@RestController
@RequestMapping("/api/v1/inference")
public class InferenceController {

	private final InferenceProxyService proxyService;
	public InferenceController(InferenceProxyService proxyService) {
		this.proxyService = proxyService;
	}

	@GetMapping("/status")
	public Map<String, Object> status() {
		InferenceProxyService.InferenceStatus status = proxyService.status();
		return Map.of(
				"reachable", status.reachable(),
				"upstreamBaseUrl", status.upstreamBaseUrl(),
				"defaultModel", status.defaultModel(),
				"modelsListed", status.modelsListed());
	}
}
