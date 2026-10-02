package com.passconsulting.passai;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;

import com.passconsulting.passai.config.PassAiProperties;

@SpringBootApplication
@EnableConfigurationProperties(PassAiProperties.class)
public class PassAiApplication {

	public static void main(String[] args) {
		SpringApplication.run(PassAiApplication.class, args);
	}
}
