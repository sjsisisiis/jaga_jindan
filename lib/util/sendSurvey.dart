import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:jaga_jindan/type/JagaJindanData.dart';
import 'package:jaga_jindan/util/RSAEncrypt.dart';
import 'package:jaga_jindan/util/notify.dart';

void showSurveyResult(
    bool success, String message, JagaJindanData credentials) {
  if (credentials.useNotification)
    noti(success ? "자가진단 제출을 성공하였습니다." : "자가진단 제출을 실패하였습니다.", message);
  else
    toast(message);
}

void sendSurvey(JagaJindanData credentials, [bool byAutomatic = false]) async {
  try {
    String jwt = jsonDecode((await http.post(
            'https://${credentials.edu}hcs.eduro.go.kr/v2/findUser',
            body: jsonEncode({
              'birthday': encrypt(credentials.birthday),
              'loginType': 'school',
              'name': encrypt(credentials.name),
              'orgCode': credentials.school,
              'stdntPNo': null
            }),
            headers: {'Content-Type': 'application/json'},
            encoding: Encoding.getByName('utf-8')))
        .body)['token'];

    if ((await http.post(
                'https://${credentials.edu}hcs.eduro.go.kr/v2/hasPassword',
                body: jsonEncode({}),
                headers: {
              'Authorization': jwt,
              'Content-Type': 'application/json'
            }))
            .body !=
        'true') {
      showSurveyResult(false, '자가진단 페이지에서 초기 비밀번호를 설정하세요.', credentials);
      return;
    }

    jwt = (await http.post(
            'https://${credentials.edu}hcs.eduro.go.kr/v2/validatePassword',
            body: jsonEncode(
                {'deviceUuid': '', 'password': encrypt(credentials.password)}),
            headers: {
          'Authorization': jwt,
          'Content-Type': 'application/json'
        }))
        .body;

    if (!jwt.contains('Bearer')) {
      showSurveyResult(false, '비밀번호를 잘못 입력했거나 로그인 시도 횟수를 초과했습니다.', credentials);
      return;
    }
    jwt = jwt.replaceAll('"', "");

    var users = jsonDecode((await http.post(
            'https://${credentials.edu}hcs.eduro.go.kr/v2/selectUserGroup',
            body: jsonEncode({}),
            headers: {
          'Authorization': jwt,
          'Content-Type': 'application/json'
        }))
        .body);

    jwt = users[0]['token'];

    var userNo = int.parse(users[0]['userPNo']);
    String org = users[0]['orgCode'];

    var userInfo = jsonDecode((await http.post(
            'https://${credentials.edu}hcs.eduro.go.kr/v2/getUserInfo',
            body: jsonEncode({'userPNo': userNo, 'orgCode': org}),
            headers: {
          'Authorization': jwt,
          'Content-Type': 'application/json'
        }))
        .body);

    if (userInfo["registerDtm"] != null) {
      var submittedDate = DateTime.parse(userInfo["registerDtm"]);

      if (submittedDate.day == DateTime.now().day &&
          byAutomatic &&
          credentials.submitLimitation) {
        showSurveyResult(false, "이미 제출한 기록이 있어 자동 제출을 취소했습니다.", credentials);
        return;
      }
    }

    jwt = userInfo['token'];

    var res = await http.post(
        'https://${credentials.edu}hcs.eduro.go.kr/registerServey',
        body: jsonEncode({
          'deviceUuid': '',
          'rspns00': 'Y',
          'rspns01': '1',
          'rspns02': '1',
          'rspns03': null,
          'rspns04': null,
          'rspns05': null,
          'rspns06': null,
          'rspns07': null,
          'rspns08': null,
          'rspns09': '0',
          'rspns10': null,
          'rspns11': null,
          'rspns12': null,
          'rspns13': null,
          'rspns14': null,
          'rspns15': null,
          'upperToken': jwt,
          'upperUserNameEncpt': userInfo['userNameEncpt']
        }),
        headers: {'Authorization': jwt, 'Content-Type': 'application/json'});

    showSurveyResult(
        true,
        "자가진단 설문이 ${DateTime.now().toString().substring(0, 19)}에 제출되었습니다.",
        credentials);
  } catch (e, s) {
    debugPrint(e.toString());
    showSurveyResult(
        false, "인증 정보를 한번 더 확인해주세요.\n오류가 계속 발생하는 경우 개발자에게 알려주세요.", credentials);
  }
}
