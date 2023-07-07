package com.demo

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "demo")
data class DemoProperties(val downstream: Downstream, val threadsleep: Threadsleep) {

    data class Downstream(
        val gateway: String = "http://localhost:8080",
        val path: String = "/api/callme",
        val host: String = "app2.demo.svc.cluster.local"
    )
    data class Threadsleep(val milliseconds: Int = 5000)
}
