package com.demo.demo

import com.demo.demo.model.Message
import org.slf4j.Logger
import org.springframework.stereotype.Component
import org.springframework.web.reactive.function.client.WebClient
import org.springframework.web.reactive.function.client.bodyToMono
import org.springframework.web.reactive.function.server.ServerRequest
import org.springframework.web.reactive.function.server.ServerResponse
import org.springframework.web.reactive.function.server.ServerResponse.ok
import org.springframework.web.reactive.function.server.body
import reactor.core.publisher.Mono
import java.time.Duration

@Component
class DemoHandler(    private val properties: DemoProperties,
                      private val webClient: WebClient,
                      private val logger: Logger
) {
    fun callSelf(request: ServerRequest): Mono<ServerResponse> {
        val messageString = Mono.justOrEmpty(request.queryParam("message")).block()

        return ok().body(Mono.just(Message(messageString.toString())))
    }

    fun callDelay(request: ServerRequest): Mono<ServerResponse> {
        val messageString = Mono.justOrEmpty(request.queryParam("message")).block()
        logger.info("running on version 2 with {} milliseconds", properties.threadsleep.milliseconds)

        return ok().body(
            Mono.
                delay(Duration.ofMillis(properties.threadsleep.milliseconds.toLong()))
                    .then(Mono.just(Message(messageString.toString())))
        )
    }

    fun callExternal(request: ServerRequest): Mono<ServerResponse> {
        val messageString =  Mono.justOrEmpty(request.queryParam("message")).block()

        logger.info(
            "calling {} on service {}",
            properties.downstream.path,
            properties.downstream.host
        )
        return ok().body(
            webClient.get()
            .uri("${properties.downstream.path}?message=$messageString")
            .retrieve().bodyToMono<String>()
        )
    }
}
