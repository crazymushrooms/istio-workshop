package com.demo.demo

import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.http.MediaType
import org.springframework.web.reactive.function.client.WebClient



@Configuration
class DemoConfig(val properties: DemoProperties) {

    @Bean
    fun webClient(): WebClient = WebClient.create(
        properties.downstream.host
    )

    @Bean
    fun router(demoHandler: DemoHandler) = org.springframework.web.reactive.function.server.router {
        accept(MediaType.APPLICATION_JSON).nest {
            GET("/self", demoHandler::callDelay)
            GET("/external", demoHandler::callExternal)
            GET("/delay", demoHandler::callDelay)
        }
    }

    @Bean
    fun logger(): Logger = LoggerFactory.getLogger(javaClass)
}
