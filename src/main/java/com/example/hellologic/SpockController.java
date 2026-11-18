package com.example.hellologic;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Random;

@RestController
@RequestMapping("/spock")
class SpockController {

    @GetMapping("/logic")
    public String hello() {
        Random random = new Random();
        Integer randomInt = random.nextInt(100);
        return randomInt+ " logic, logic, logic!";
    }
}
