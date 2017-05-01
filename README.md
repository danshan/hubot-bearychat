# hubot-slack

[![Build Status](https://travis-ci.org/danshan/hubot-slack.svg?branch=master)](https://travis-ci.org/danshan/hubot-slack)
[![](https://images.microbadger.com/badges/image/danshan/hubot-slack.svg)](https://microbadger.com/images/danshan/hubot-slack "Get your own image badge on microbadger.com")
[![](https://images.microbadger.com/badges/version/danshan/hubot-slack.svg)](https://microbadger.com/images/danshan/hubot-slack "Get your own version badge on microbadger.com")


```yaml
hubot-slack:
  image: daocloud.io/danshan/hubot-slack:latest
  privileged: false
  restart: always
  environment:
  - HUBOT_SLACK_TOKEN=
  - HUBOT_LOG_LEVEL=debug
  - HUBOT_NAME=siri
```