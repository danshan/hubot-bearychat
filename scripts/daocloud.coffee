# Description:
#   对接daocloud api
#
# Dependencies:
#
# Configuration:
#   DAOCLOUD_TOKEN
#
# Commands:
#   hubot dc app list - 获取用户的 app 列表
#   hubot dc app info <app_id> - 获取单个 App
#   hubot dc app info <index> - 获取单个 App
#   hubot dc app start|stop|restart <index> - 执行单个 App
#   hubot dc app redeploy <index> <release_name> - 重新部署单个 App
#   hubot dc app action <app_index> - 获取 App 的 Action
#   hubot dc app action <app_index> <action_index> - 获取事件 Action
#
# Notes:
#
# Author:
#   danshan

querystring = require 'querystring'

appList = []
actionList = {}
appNameList = {}

listApps = (msg) ->
  token = process.env.DAOCLOUD_TOKEN
  url = "https://openapi.daocloud.io/v1/apps"
  req = msg.http(url)
  req.header("Authorization", "token " + token)

  req.get() (err, res, body) ->
    if (err)
      msg.reply "DaoCloud says: #{err}"
      return

    json = JSON.parse(body)
    if (res.statusCode < 200 || res.statusCode >= 300)
      sendErr msg, json.error_id, json.message
      return

    attachments = []
    for app in json.app
      index = appList.indexOf app.id
      if index == -1
        appList.push app.id
        appNameList[app.id] = app.name

      index = appList.indexOf app.id
      attachments.push({
        title: "#{index + 1}. #{app.name} : #{app.id}",
        text: "#{app.package.image} : *#{app.release_name}* : `#{app.state}`",
        fields: [
          {title: "Last Operated", value: "#{new Date(app.last_operated_at).toLocaleString()}", short: true},
          {title: "Auto Redeploy", value: "#{app.enable_auto_redeploy}", short: true}
        ],
        color: (chooseColor app.state),
        mrkdwn_in: ["text"]
      })
      if attachments.length >= 30
        break;

    message = {
      text: "App List"
      attachments: JSON.stringify attachments,
      username: process.env.HUBOT_NAME,
      as_user: true,
      mrkdwn_in: ["text"]
    }
    console.log JSON.stringify message
    msg.reply message

loadAppByIndex = (msg, index) ->
  app_id = appList[index]
  if !app_id
    msg.reply "app index not found."
    return
  loadAppById msg, app_id

loadAppById = (msg, app_id) ->
  token = process.env.DAOCLOUD_TOKEN
  url = "https://openapi.daocloud.io/v1/apps/#{app_id}"
  req = msg.http(url)
  req.header("Authorization", "token " + token)

  req.get() (err, res, body) ->
    if (err)
      msg.reply "DaoCloud says: #{err}"
      return

    console.log body
    json = JSON.parse(body)
    if (res.statusCode < 200 || res.statusCode >= 300)
      sendErr msg, json.error_id, json.message
      return

    command = ""
    if json.config.command != undefined
      command = json.config.command
    ports = []
    for port in json.config.expose_ports
      ports.push("#{port.host_port}:#{port.container_port}")

    attachments = []
    attachments.push({
      title: "#{json.name}",
      text: "#{json.package.image} : *#{json.release_name}* : `#{json.state}`"
      color: (chooseColor json.state),
      fields: [
        {title: "Last Operated", value: "#{new Date(json.last_operated_at).toLocaleString()}", short: true},
        {title: "Auto Redeploy", value: "#{json.enable_auto_redeploy}", short: true}
        {title: "Command", value: "#{command}", short: false}
        {title: "Ports", value: "#{ports}", short: false}
      ],
      mrkdwn_in: ["text"]
    })

    message = {
      text: "app info: *#{appNameList[app_id]}* #{app_id}"
      attachments: JSON.stringify attachments,
      username: process.env.HUBOT_NAME,
      as_user: true,
      mrkdwn_in: ["text"]
    }
    console.log JSON.stringify message
    msg.reply message

operateAppByIndex = (msg, app_index, action, release_name) ->
  app_id = appList[app_index]
  if !app_id
    msg.reply "app index not found."
    return

  token = process.env.DAOCLOUD_TOKEN
  url = "https://openapi.daocloud.io/v1/apps/#{app_id}/actions/#{action}"
  req = msg.http(url)
  req.header("Authorization", "token " + token)
  if release_name
    post_data = {}
    post_data.release_name = release_name
    post_str = JSON.stringify post_data
  else
    post_str = ""

  req.post(post_str) (err, res, body) ->
    if (err)
      msg.reply "DaoCloud says: #{err}"
      return

    console.log body
    json = JSON.parse(body)
    if (res.statusCode < 200 || res.statusCode >= 300)
      sendErr msg, json.error_id, json.message
      return

    action_id = json.action_id
    if actionList.app_id == undefined
      actionList.app_id = []
    actionList.app_id.push(action_id)
    action_index = actionList.app_id.indexOf action_id

    attachments = []
    attachments.push({
      title: "Action: #{action} #{app_id}",
      text: "Action ID: `#{app_index + 1}` - `#{action_index + 1}` *#{action_id}*",
      color: "good",
      mrkdwn_in: ["text"]
    })

    message = {
      text: "#{action} app: #{app_index + 1}. *#{appNameList[app_id]}* #{app_id}"
      attachments: JSON.stringify attachments,
      username: process.env.HUBOT_NAME,
      as_user: true,
      mrkdwn_in: ["text"]
    }
    console.log JSON.stringify message
    msg.reply message

findActionByAppIndex = (msg, app_index) ->
  app_id = appList[app_index]
  if !app_id
    msg.reply "app index not found."
    return

  if actionList.app_id == undefined
    msg.reply "app has no action."
    return

  actions = actionList.app_id
  start = 0
  finish = actions.length - 1
  if actions.length > 30
    start = actions.length - 30

  attachments = []
  while finish >= start
    attachments.push({
      title: "#{finish + 1}. #{actions[finish]}",
      color: "good",
      mrkdwn_in: ["text"]
    })
    finish--

  message = {
    text: "action list: #{app_index + 1}. *#{appNameList[app_id]}* #{app_id}"
    attachments: JSON.stringify attachments,
      username: process.env.HUBOT_NAME,
      as_user: true,
      mrkdwn_in: ["text"]
  }
  console.log JSON.stringify message
  msg.reply message

loadActionByIndex = (msg, app_index, action_index) ->
  app_id = appList[app_index]
  if !app_id
    msg.reply "app index not found."
    return
  action_id = actionList.app_id[action_index]
  if !action_id
    msg.reply "action index not found."
    return

  token = process.env.DAOCLOUD_TOKEN
  url = "https://openapi.daocloud.io/v1/apps/#{app_id}/actions/#{action_id}"
  req = msg.http(url)
  req.header("Authorization", "token " + token)

  req.get() (err, res, body) ->
    if (err)
      msg.reply "DaoCloud says: #{err}"
      return

    console.log body
    json = JSON.parse(body)
    if (res.statusCode < 200 || res.statusCode >= 300)
      sendErr msg, json.error_id, json.message
      return

    attachments = []
    attachment = {
      title: "#{appNameList[app_id]} #{json.action_name} #{json.state}",
      text: "App ID: *#{app_id}*\nAction ID: *#{action_id}*",
      fields: [
        {title: "Action Name", value: "#{json.action_name}", short: true},
        {title: "State", value: "#{json.state}", short: true},
        {title: "Time Cost", value: "#{json.time_cost_seconds}s", short: true},
        {title: "Error Message", value: "#{json.error_info.message}", short: false},
        {title: "Start Time", value: "#{new Date(json.start_date).toLocaleString()}", short: true},
        {title: "End Time", value: "#{new Date(json.end_date).toLocaleString()}", short: true}
      ],
      color: (chooseColor json.state),
      mrkdwn_in: ["text"]
    }
    attachments.push(attachment)

    message = {
      text: "action info: #{app_index + 1}. #{appNameList[app_id]} #{app_id}"
      attachments: JSON.stringify attachments,
        username: process.env.HUBOT_NAME,
        as_user: true,
        mrkdwn_in: ["text"]
    }
    console.log JSON.stringify message
    msg.reply message


chooseColor = (state) ->
  if /running/i.test state
    return "good"
  if /success/i.test state
    return "good"
  if /failed/i.test state
    return "danger"
  if /stopped/i.test state
    return "danger"
  return "warning"

sendErr = (msg, error_id, error_message) ->
  message = {
    attachments: [{
      title: "#{error_id}",
      text: "#{error_message}"
      color: "bad",
      fallback: "#{error_id}"
    }],
    username: process.env.HUBOT_NAME,
    as_user: true
  }
  console.error JSON.stringify message
  msg.reply message

module.exports = (robot) ->
  robot.respond /dc\s+app\s+list\s*$/i, (msg) ->
    listApps msg

  robot.respond /dc\s+app\s+info\s+(\S+){36}\s*$/i, (msg) ->
    loadAppById msg, msg.match[1]

  robot.respond /dc\s+app\s+info\s+(\d+)\s*$/i, (msg) ->
    loadAppByIndex msg, msg.match[1] - 1

  robot.respond /dc\s+app\s+(start|stop|restart)\s+(\d+)\s*$/i, (msg) ->
    operateAppByIndex msg, msg.match[2] - 1, msg.match[1]

  robot.respond /dc\s+app\s+(redeploy)\s+(\d+)\s+(\S+)\s*$/i, (msg) ->
    operateAppByIndex msg, msg.match[2] - 1, msg.match[1], msg.match(3)

  robot.respond /dc\s+app\s+action\s+(\d+)\s*$/i, (msg) ->
    findActionByAppIndex msg, msg.match[1] - 1

  robot.respond /dc\s+app\s+action\s+(\d+)\s+(\d+)\s*$/i, (msg) ->
    loadActionByIndex msg, msg.match[1] - 1, msg.match[2] - 1
