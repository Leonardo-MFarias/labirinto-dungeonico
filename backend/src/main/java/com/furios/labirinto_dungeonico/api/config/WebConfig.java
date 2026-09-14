package com.furios.labirinto_dungeonico.api.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Libera CORS para os endpoints REST a partir de origens de desenvolvimento local
 * (o app Flutter web roda em uma porta própria, ex.: `flutter run -d chrome`). Restrito a
 * `localhost`/`127.0.0.1` em vez de `*` (RNF-24); revisar antes de qualquer publicação fora
 * do ambiente de desenvolvimento.
 */
@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
                .allowedOriginPatterns("http://localhost:*", "http://127.0.0.1:*")
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS");
    }
}
