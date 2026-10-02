package com.passconsulting.passai.api;

import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.passconsulting.passai.inference.ModelCatalogService;

@RestController
@RequestMapping("/api/v1/inference")
public class ActiveModelController {

	private final ModelCatalogService catalogService;

	public ActiveModelController(ModelCatalogService catalogService) {
		this.catalogService = catalogService;
	}

	@GetMapping("/catalog")
	public Map<String, Object> catalog() {
		return catalogService.catalogResponse();
	}

	@PostMapping("/active-model")
	public Map<String, String> setActiveModel(@RequestBody Map<String, String> body) {
		String modelId = body.get("modelId");
		if (modelId == null || modelId.isBlank()) {
			throw new IllegalArgumentException("modelId is required");
		}
		catalogService.ensureActiveModel(modelId);
		return Map.of("modelId", modelId, "status", "ready");
	}
}
