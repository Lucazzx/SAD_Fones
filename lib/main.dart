import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Escolha seu Fone',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: PreferencePage(),
    );
  }
}

class PreferencePage extends StatefulWidget {
  @override
  _PreferencePageState createState() => _PreferencePageState();
}

class _PreferencePageState extends State<PreferencePage> {
  double _minPrice = 0;
  double _maxPrice = 1000;
  String _selectedType = 'Intra Auricular';
  bool _isForWork = false;
  bool _isForGaming = false;
  bool _isForPhysicalActivity = false;
  List<String> _types = ['Intra Auricular', 'Auricular'];

  void _navigateToResults() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultPage(
          minPrice: _minPrice,
          maxPrice: _maxPrice,
          selectedType: _selectedType,
          isForWork: _isForWork,
          isForGaming: _isForGaming,
          isForPhysicalActivity: _isForPhysicalActivity,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Preferências de Fone'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Faixa de Preço'),
            RangeSlider(
              values: RangeValues(_minPrice, _maxPrice),
              min: 0,
              max: 5000,
              divisions: 100,
              labels: RangeLabels(
                _minPrice.toString(),
                _maxPrice.toString(),
              ),
              onChanged: (RangeValues values) {
                setState(() {
                  _minPrice = values.start;
                  _maxPrice = values.end;
                });
              },
            ),
            SizedBox(height: 20),
            Text('Tipo de Fone'),
            DropdownButton<String>(
              value: _selectedType,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedType = newValue!;
                });
              },
              items: _types.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            SizedBox(height: 20),
            CheckboxListTile(
              title: Text('Para Trabalho (Microfone de Qualidade)'),
              value: _isForWork,
              onChanged: (bool? value) {
                setState(() {
                  _isForWork = value!;
                });
              },
            ),
            CheckboxListTile(
              title: Text('Para Jogos (Modo Jogo)'),
              value: _isForGaming,
              onChanged: (bool? value) {
                setState(() {
                  _isForGaming = value!;
                });
              },
            ),
            CheckboxListTile(
              title: Text('Para Atividade Física (Resistência à Água)'),
              value: _isForPhysicalActivity,
              onChanged: (bool? value) {
                setState(() {
                  _isForPhysicalActivity = value!;
                });
              },
            ),
            ElevatedButton(
              onPressed: _navigateToResults,
              child: Text('Ver Resultados'),
            ),
          ],
        ),
      ),
    );
  }
}

class ResultPage extends StatefulWidget {
  final double minPrice;
  final double maxPrice;
  final String selectedType;
  final bool isForWork;
  final bool isForGaming;
  final bool isForPhysicalActivity;

  ResultPage({
    required this.minPrice,
    required this.maxPrice,
    required this.selectedType,
    required this.isForWork,
    required this.isForGaming,
    required this.isForPhysicalActivity,
  });

  @override
  _ResultPageState createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  List<List<dynamic>> _fones = [];
  List<List<dynamic>> _filteredFones = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCSV();
  }

  void _loadCSV() async {
    try {
      final rawData = await rootBundle.loadString('assets/db_fones.csv');
      List<List<dynamic>> listData = CsvToListConverter().convert(rawData);
      setState(() {
        _fones = listData;
        _filterFones();
      });
    } catch (e) {
      print("Error loading CSV: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterFones() {
    List<List<dynamic>> filtered = _fones.where((fone) {
      if (fone[0] == 'modelo') return false; // Skip header
      double price = double.tryParse(fone[2].toString()) ?? 0;
      String type = fone[1].toString();
      double micQuality = double.tryParse(fone[8].toString()) ?? 0; // microfone
      String hasGameMode = fone[9].toString(); // possui_modo_jogo
      String resistance = fone[10].toString(); // resistencia
      return price >= widget.minPrice &&
          price <= widget.maxPrice &&
          type == widget.selectedType &&
          (!widget.isForWork || micQuality > 0) &&
          (!widget.isForGaming || hasGameMode == 'Sim') &&
          (!widget.isForPhysicalActivity || resistance != 'N/A');
    }).toList();
    filtered.sort((a, b) {
      double ratingA = double.tryParse(a[3].toString()) ?? 0;
      double ratingB = double.tryParse(b[3].toString()) ?? 0;
      return ratingB.compareTo(ratingA); // Sort by rating descending
    });
    setState(() {
      _filteredFones = filtered.take(5).toList(); // Top 5
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Resultados'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _filteredFones.isEmpty
              ? Center(
                  child: Text(
                      'Nenhum fone encontrado com os critérios selecionados.'))
              : ListView.builder(
                  itemCount: _filteredFones.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title:
                          Text(_filteredFones[index][0].toString()), // modelo
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'R\$ ${_filteredFones[index][2].toString()} - Nota: ${_filteredFones[index][3].toString()}'), // preço_medio_reais e nota_global
                          Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  _launchURL(_filteredFones[index][11]
                                      .toString()); // link_review
                                },
                                child: Text('Review'),
                              ),
                              TextButton(
                                onPressed: () {
                                  _launchURL(_filteredFones[index][12]
                                      .toString()); // link_amazon
                                },
                                child: Text('Comprar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  void _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }
}
