# Description:
#   查询百度地图信息
#
# Dependencies:
#
# Configuration:
#   BAIDU_MAP_AK
#
# Commands:
#   hubot map <location> - 通过百度地图搜索指定位置
#   hubot 开车从 <fromcity> <from> 到 <tocity> <to> - 驾车导航模式
#   hubot 步行从 <fromcity> <from> 到 <tocity> <to> - 驾车导航模式
#   hubot 骑车从 <fromcity> <from> 到 <tocity> <to> - 骑行导航模式
#   hubot 公交从 <fromcity> <from> 到 <tocity> <to> - 公交导航模式
#
# Notes:
#
# Author:
#   danshan

querystring = require 'querystring'

searchMap = (robot, msg) ->
  ak = process.env.BAIDU_MAP_AK
  title = msg.match[1]
  query = querystring.escape title
  width_l = 320
  height_l = 240
  width_s = 75
  height_s = 75
  zoom = 16
  message = {
    attachments: [{
      title: "#{title}",
      title_link: "https://api.map.baidu.com/geocoder?address=#{query}&output=html"
      color: "good",
      fallback: "#{title}",
      image_url: "https://api.map.baidu.com/staticimage/v2?ak=#{ak}&center=#{query}&width=#{width_l}&height=#{height_l}&zoom=#{zoom}&markers=#{query}",
      thumb_url: "https://api.map.baidu.com/staticimage/v2?ak=#{ak}&center=#{query}&width=#{width_s}&height=#{height_s}&zoom=#{zoom}&markers=#{query}"
    }],
    username: process.env.HUBOT_NAME,
    as_user: true
  }

  console.log JSON.stringify message
  msg.reply message

navigate = (robot, msg, mode) ->
  ak = process.env.BAIDU_MAP_AK

  origin_region = msg.match[1]
  origin = msg.match[2]
  region = origin_region
  destination_region = msg.match[3]
  destination = msg.match[4]

  console.log "mode=#{mode}, origin=#{origin_region} : #{origin}, dest=#{destination_region} : #{destination}"
  url = "http://api.map.baidu.com/direction/v1?mode=#{mode}&origin=#{origin}&destination=#{destination}&region=#{region}&origin_region=#{origin_region}&destination_region=#{destination_region}&output=json&ak=#{ak}"
  console.log url

  req = msg.http(url)

  req.header('Content-Length', 0)
  req.get() (err, res, body) ->
    if err
      msg.reply "Baidu says: #{err}"
      return

    json = JSON.parse(body)
    if json.status != 0
      msg.reply "Baidu says: #{json.message}"
      return

    console.log "type=#{json.type}"
    if json.type == 2 # 起/终点唯一
      navigateCertain msg, mode, json.result
    else
      navigateUncertain msg, mode, json.result

praseInstruction = (instructions) ->
  return instructions.replace(/<b>/g, " *").replace(/<\/b>/g, "* ").replace(/<font.+?>/g, "*").replace(/<\/font>/g, "*").replace(/\*\*/g, "*")

mergeSteps = (steps) ->
  attaText = ""
  for step in steps
    attaText += praseInstruction step.instructions + "\n"
  return attaText

mergeSchemeSteps = (steps) ->
  attaText = ""
  for step in steps # also array
    for st in step
      if st.stepInstruction != undefined
        attaText += praseInstruction st.stepInstruction + "\n"
  return attaText


navigateCertain = (msg, mode, result) ->
  origin = result.origin
  destination = result.destination
  routes = result.routes
  taxi = result.taxi

  if routes == undefined || routes.length == 0
    msg.reply "路线查询失败"
    return
  attachments = []

  if routes[0].scheme != undefined && routes[0].scheme.length > 0
    attaText = mergeSchemeSteps routes[0].scheme[0].steps
  else
    attaText = mergeSteps routes[0].steps

  if !attaText
    msg.reply "不支持的数据格式"
    return

  attachments.push({
    "text": attaText,
    "color": "good",
    "mrkdwn_in": ["text"]
  })

  text = ""
  if origin.wd!= undefined && destination.wd != undefined
    text += "从 *#{origin.cname} #{origin.wd}* 到 *#{destination.cname} #{destination.wd}*"
  if taxi != undefined
    if text != ""
      text += "\n"
    text += "Taxi 全程 #{(taxi.distance).toLocaleString('en-US')}米, #{Math.ceil(taxi.duration/60)}分钟, #{taxi.detail[0].total_price}元"


  message = {
    text: text,
    attachments: JSON.stringify attachments,
    username: process.env.HUBOT_NAME,
    as_user: true,
    mrkdwn_in: ["text"]
  }
  console.log JSON.stringify message
  msg.reply message

navigateUncertain = (msg, mode, result) ->
  origin = result.origin
  destination = result.destination


module.exports = (robot) ->
  robot.respond /map?\s+(.+)/i, (msg) ->
    searchMap robot, msg

  robot.respond /(?:开车|驾车)\s*从\s*(\S+)\s+(.+)\s*到\s*(\S+)\s+(.+)\s*/i, (msg) ->
    navigate robot, msg, "driving"

  robot.respond /(?:走路|步行)\s*从\s*(\S+)\s+(.+)\s*到\s*(\S+)\s+(.+)\s*/i, (msg) ->
    navigate robot, msg, "walking"

  robot.respond /(?:公交)\s*从\s*(\S+)\s+(.+)\s*到\s*(\S+)\s+(.+)\s*/i, (msg) ->
    navigate robot, msg, "transit"

  robot.respond /(?:骑行|骑车)\s*从\s*(\S+)\s+(.+)\s*到\s*(\S+)\s+(.+)\s*/i, (msg) ->
    navigate robot, msg, "riding"
