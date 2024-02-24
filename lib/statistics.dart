import 'package:cgk/qa.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';

class stat extends StatelessWidget {
  const stat({super.key});

  @override
  Widget build(BuildContext context) {
    var alq = 12; //Общее кол-во вопросов
    var vzq = 6; //Кол-во взятых вопросов
    return Scaffold(
      backgroundColor: const Color(0xff3987c8),
      appBar: AppBar(
        backgroundColor: const Color(0xff418ecd),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            const Text(
              'Статистика:',
              style: TextStyle(
                fontSize: 30,
              ),
            ),
            Text(
              'Общее кол-во вопросов: $alq',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 25),
            CircularPercentIndicator(
              radius: 105.0,
              lineWidth: 20.0,
              animation: true,
              animationDuration: 1000,
              percent: vzq / alq,
              center: Text(
                '${(vzq / alq * 100).round()}%',
                style: const TextStyle(fontSize: 40),
              ),
              circularStrokeCap: CircularStrokeCap.round,
              progressColor: Colors.yellow,
              backgroundColor: Colors.black,
            ),
            const SizedBox(height: 25),
            Text(
              'Кол-во взятых вопросов: $vzq.',
              style: const TextStyle(fontSize: 20),
            ),
          ],
        ),
      ),
    );
  }
}
