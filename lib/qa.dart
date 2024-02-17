import 'dart:async';
import 'package:cgk/navigation.dart';
import 'package:cgk/select_questions.dart';
import 'package:cgk/value_union_state_listener.dart';
import 'package:cgk/union_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

//парсинг к нужному типу
extension TypeCast<T> on T? {
  R safeCast<R>() {
    final value = this;
    if (value is R) return value;
    throw Exception('не удалось привести тип $runtimeType к типу $R');
  }
}

//класс для вопросов и ответов
class QA {
  final int id;
  final String question;
  final String answer;

  const QA({
    required this.id,
    required this.question,
    required this.answer,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QA &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          question == other.question &&
          answer == other.answer;

  @override
  int get hashCode => id.hashCode ^ question.hashCode ^ answer.hashCode;
}

bool timeGame = false;

GlobalKey<_QuestionTimerState> globalKey = GlobalKey();

class Training extends StatefulWidget {
  const Training({super.key});

  @override
  State<Training> createState() => _TrainingState();
}

final answered = <int>[];
final moved = <int>{};
int questionIndex = 0;
int last = 1;

Future hideBar() async {
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
      overlays: [SystemUiOverlay.top]);
}

String twoDigits(int n) {
  return n.toString().padLeft(2, '0');
}

class QuestionTimer extends StatefulWidget {
  final VoidCallback notifyParent;
  final List<QA> questions;

  QuestionTimer({Key? key, required this.notifyParent, required this.questions})
      : super(key: key);

  @override
  State<QuestionTimer> createState() => _QuestionTimerState();
}

class _QuestionTimerState extends State<QuestionTimer> {
  Duration duration = Duration(seconds: 2);
  static const contDownDuration = Duration(seconds: 2);
  Timer? timer;

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void addTime() {
    final addSeconds = -1;
    final seconds = duration.inSeconds + addSeconds;
    if (seconds < 0) {
      timer?.cancel();
      last++;
      if (questionIndex < widget.questions.length - 1) {
        questionIndex++;
        moved.add(widget.questions[questionIndex].id);
      }
      widget.notifyParent();
      reset();
    } else {
      duration = Duration(seconds: seconds);
    }
    setState(() {});
  }

  void startTimer() {
    timer = Timer.periodic(Duration(seconds: 1), (_) => addTime());
  }

  void reset() {
    duration = contDownDuration;
    if (last != widget.questions.length + 1) {
      startTimer();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff3987c8),
      body: Center(
        child: Text(
          '${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}',
          style: TextStyle(fontSize: 80),
        ),
      ),
    );
  }
}

class _TrainingState extends State<Training> {
  final qaState = ValueNotifier<UnionState<List<QA>>>(UnionState$Loading());

  //чтение данных из бд
  Future<List<QA>> readData() async {
    final response = await Supabase.instance.client.from('questions').select();
    if (response is! Object) throw Exception('результат равен null');
    return response
        .safeCast<List<Object?>>()
        .map((e) => e.safeCast<Map<String, Object?>>())
        .map(
          (e) => QA(
            id: e['id'].safeCast<int>(),
            question: e['question'].safeCast<String>(),
            answer: e['answer'].safeCast<String>(),
          ),
        )
        .toList();
  }

  //обновление экрана при разных состояниях
  Future<void> updateScreen() async {
    try {
      qaState.value = UnionState$Loading();
      final data = await readData();
      data.shuffle();
      qaState.value = UnionState$Content(data.take(selected.toInt()).toList());
    } on Exception {
      qaState.value = UnionState$Error();
    }
  }

  @override
  void initState() {
    updateScreen();
    hideBar();
    super.initState();
  }

  @override
  void dispose() {
    qaState.dispose();
    super.dispose();
  }

  void refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff3987c8),
      appBar: AppBar(
        backgroundColor: const Color(0xff418ecd),
      ),
      drawer: const Navigation(),
      body: ValueUnionStateListener<List<QA>>(
        unionListenable: qaState,
        contentBuilder: (content) {
          if (content.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Ошибка, перезагрузите страницу'),
                  ElevatedButton(
                    onPressed: () {
                      updateScreen();
                    },
                    child: const Text('Обновить'),
                  ),
                ],
              ),
            );
          }
          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              last == content.length + 1
                  ? SizedBox.shrink()
                  : SizedBox(
                      height: 130,
                      child: timeGame
                          ? QuestionTimer(
                              notifyParent: refresh,
                              questions: content,
                              key: globalKey)
                          : SizedBox.shrink(),
                    ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  timeGame
                      ? SizedBox(
                          width: 60,
                        )
                      : IconButton(
                          onPressed: () {
                            if (questionIndex != 0) {
                              questionIndex--;
                            } else {
                              return;
                            }
                            setState(() {});
                          },
                          icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          iconSize: 50,
                          color: Colors.black45,
                        ),
                  last == content.length + 1
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.all(
                              Radius.circular(20),
                            ),
                          ),
                          child: SizedBox(
                            height: 360,
                            width: 270,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 20, horizontal: 5),
                                child: Column(
                                  children: [
                                    Text(
                                      'Всего вопросов: ${timeGame ? content.length : moved.length}',
                                      style: TextStyle(
                                        fontSize: 25,
                                      ),
                                    ),
                                    Text(
                                      'Вопросов взято: ${answered.length}',
                                      style: TextStyle(
                                        fontSize: 25,
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        last = 1;
                                        questionIndex = 0;
                                        selected = 1;
                                        timeGame = false;
                                        moved.clear();
                                        answered.clear();
                                        Navigator.pushAndRemoveUntil(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const SelectQuestion(),
                                            ),
                                            (route) => false);
                                      },
                                      child: Text('Домой'),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : Expanded(
                          flex: 1,
                          child: SizedBox(
                            height: 300,
                            width: 220,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black),
                                color: const Color(0xbf418ecd),
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(20),
                                ),
                              ),
                              child: InkWell(
                                highlightColor: Colors.black38,
                                splashColor: Colors.black26,
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(20),
                                ),
                                onLongPress: () {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext builder) {
                                      return AlertDialog(
                                        contentPadding:
                                            const EdgeInsets.all(24),
                                        content: Text(
                                          content[questionIndex].question,
                                          textAlign: TextAlign.center,
                                        ),
                                        backgroundColor: Colors.blueGrey,
                                      );
                                    },
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: SingleChildScrollView(
                                    key: ValueKey(questionIndex),
                                    scrollDirection: Axis.vertical,
                                    child: Text(
                                      content[questionIndex].question,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                  timeGame
                      ? SizedBox(
                          width: 60,
                        )
                      : IconButton(
                          iconSize: 50,
                          onPressed: () {
                            if (questionIndex < content.length - 1) {
                              questionIndex++;
                            } else {
                              return;
                            }
                            moved.add(content[questionIndex].id);
                            setState(() {});
                          },
                          icon: const Icon(Icons.arrow_forward_ios_rounded),
                          color: Colors.black45,
                        )
                ],
              ),
              Center(
                child: last == content.length + 1
                    ? SizedBox.shrink()
                    : SizedBox(
                        width: 100,
                        height: 40,
                        child: ElevatedButton(
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.all(
                                const Color(0xff418ecd)),
                            shadowColor: MaterialStateProperty.all(
                                const Color(0xff418ecd)),
                            overlayColor:
                                MaterialStateProperty.all(Colors.black12),
                            shape: MaterialStateProperty.all<
                                RoundedRectangleBorder>(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: Colors.black),
                              ),
                            ),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  contentPadding: const EdgeInsets.all(24),
                                  content: Text(
                                    content[questionIndex].answer,
                                    textAlign: TextAlign.center,
                                  ),
                                  backgroundColor: Colors.blueGrey,
                                );
                              },
                            );
                          },
                          child: const Text(
                            'Ответ',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
              ),
              Row(
                children: [
                  last == content.length + 1
                      ? SizedBox.shrink()
                      : Container(
                          height: 210,
                          width: MediaQuery.of(context).size.width,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: SizedBox(
                                    width: 250,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: timeGame
                                          ? () {
                                              if (questionIndex !=
                                                  content.length - 1) {
                                                answered.contains(
                                                        content[questionIndex]
                                                            .id)
                                                    ? null
                                                    : answered.add(
                                                        content[questionIndex]
                                                            .id);
                                                moved.add(
                                                    content[questionIndex].id);
                                                questionIndex++;
                                                last++;
                                                globalKey.currentState?.timer
                                                    ?.cancel();
                                                globalKey.currentState?.reset();
                                                setState(() {});
                                              } else {
                                                answered.add(
                                                    content[questionIndex].id);
                                                globalKey.currentState?.timer
                                                    ?.cancel();
                                                last++;
                                                setState(
                                                  () {},
                                                );
                                              }
                                            }
                                          : answered.contains(
                                                  content[questionIndex].id)
                                              ? null
                                              : () {
                                                  answered.add(
                                                      content[questionIndex]
                                                          .id);
                                                  setState(
                                                    () {},
                                                  );
                                                },
                                      style: ButtonStyle(
                                        backgroundColor: answered.contains(
                                                content[questionIndex].id)
                                            ? MaterialStateProperty.all(
                                                const Color(0xff235d8c))
                                            : MaterialStateProperty.all(
                                                const Color(0xff418ecd)),
                                        shadowColor: answered.contains(
                                                content[questionIndex].id)
                                            ? MaterialStateProperty.all(
                                                const Color(0xff235d8c))
                                            : MaterialStateProperty.all(
                                                const Color(0xff418ecd)),
                                        overlayColor: MaterialStateProperty.all(
                                            const Color(0xff235d8c)),
                                        shape: MaterialStateProperty.all<
                                            RoundedRectangleBorder>(
                                          RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            side: const BorderSide(
                                                color: Colors.black),
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Вопрос взят',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                        )
                ],
              ),
            ],
          );
        },
        loadingBuilder: () {
          return const SafeArea(
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.white60,
              ),
            ),
          );
        },
        errorBuilder: () {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Ошибка, перезагрузите страницу'),
                ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor:
                        MaterialStateProperty.all(const Color(0xff418ecd)),
                    shadowColor:
                        MaterialStateProperty.all(const Color(0xff418ecd)),
                  ),
                  onPressed: () {
                    updateScreen();
                  },
                  child: const Text('Обновить',
                      style: TextStyle(color: Colors.black)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
