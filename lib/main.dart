import 'dart:math';
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
              max: 1000,
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

//Sumarização
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
  List<List<dynamic>> _filteredFonesCustoBeneficio = [];
  List<List> _filteredFonesBoasApostas = <List<dynamic>>[];
  List<List<dynamic>> _filteredFonesConsolidados = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCSV();
  }

//Carrega o CSV
  void _loadCSV() async {
    try {
      final rawData = await rootBundle.loadString('assets/db_fones.csv');
      List<List<dynamic>> listData = CsvToListConverter().convert(rawData);
      setState(() {
        _fones = listData;
        _applyClustering();
      });
    } catch (e) {
      print("Error loading CSV: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

//Agrupamento
  void _applyClustering() {
    List<List<double>> dataPoints = _fones.skip(1).map((fone) {
      return [
        double.tryParse(fone[2].toString()) ?? 0, // preço_medio_reais
        double.tryParse(fone[3].toString()) ?? 0, // nota_global
        double.tryParse(fone[4].toString()) ?? 0, // som
        double.tryParse(fone[5].toString()) ?? 0, // anc (cancelamento de ruído)
        double.tryParse(fone[6].toString()) ?? 0, // autonomia_horas
      ];
    }).toList();

    //K-Means clustering
    var kmeans = KMeans(numClusters: 3);
    var result = kmeans.fit(dataPoints);

    var clusteredFones = <int, List<List<dynamic>>>{};
    for (int i = 0; i < result.clusterIndices.length; i++) {
      var cluster = result.clusterIndices[i];
      if (!clusteredFones.containsKey(cluster)) {
        clusteredFones[cluster] = [];
      }
      clusteredFones[cluster]!.add(_fones[i + 1]);
    }

    // Identica clusters
    var largestCluster =
        clusteredFones.values.reduce((a, b) => a.length > b.length ? a : b);
    var smallestCluster =
        clusteredFones.values.reduce((a, b) => a.length < b.length ? a : b);
    var averageCluster = clusteredFones.values.firstWhere(
        (cluster) =>
            cluster.length != largestCluster.length &&
            cluster.length != smallestCluster.length,
        orElse: () => []);

    // Performa Análise fatorial usando PCA (Principal Component Analysis)
    var pca = PCA(numComponents: 2);
    var pcaResult = pca.fit(largestCluster
        .map((fone) => [
              double.tryParse(fone[2].toString()) ?? 0, // preço_medio_reais
              double.tryParse(fone[3].toString()) ?? 0, // nota_global
              double.tryParse(fone[4].toString()) ?? 0, // som
              double.tryParse(fone[5].toString()) ??
                  0, // anc (cancelamento de ruído)
              double.tryParse(fone[6].toString()) ?? 0, // autonomia_horas
            ])
        .toList());

    // Extrair cargas fatoriais e scores
    var factorLoadings = pcaResult.loadings;
    var factorScores = pcaResult.scores;

    // Filtra os custo beneficios
    var filteredFonesCustoBeneficio = <List<dynamic>>[];
    for (var fone in largestCluster) {
      double price = double.tryParse(fone[2].toString()) ?? 0;
      String type = fone[1].toString();
      double micQuality = double.tryParse(fone[8].toString()) ?? 0; // microfone
      String hasGameMode = fone[9].toString(); // possui_modo_jogo
      String resistance = fone[10].toString(); // resistencia
      if (price >= widget.minPrice &&
          price <= widget.maxPrice &&
          type == widget.selectedType &&
          (!widget.isForWork || micQuality > 0) &&
          (!widget.isForGaming || hasGameMode == 'Sim') &&
          (!widget.isForPhysicalActivity || resistance != 'N/A')) {
        filteredFonesCustoBeneficio.add(fone);
      }
    }

    // Rankeia com base no factor score
    filteredFonesCustoBeneficio.sort((a, b) {
      double scoreA =
          factorScores[largestCluster.indexOf(a)].reduce((a, b) => a + b);
      double scoreB =
          factorScores[largestCluster.indexOf(b)].reduce((a, b) => a + b);
      return scoreB.compareTo(scoreA);
    });

    // Seleciona o top 3 de custo beneficio
    _filteredFonesCustoBeneficio = filteredFonesCustoBeneficio.take(3).toList();

    //filtra os consolidados
    var filteredFonesConsolidados = <List<dynamic>>[];
    for (var fone in averageCluster) {
      double price = double.tryParse(fone[2].toString()) ?? 0;
      String type = fone[1].toString();
      double micQuality = double.tryParse(fone[8].toString()) ?? 0; // microfone
      String hasGameMode = fone[9].toString(); // possui_modo_jogo
      String resistance = fone[10].toString(); // resistencia
      if (price >= widget.minPrice &&
          price <= widget.maxPrice &&
          type == widget.selectedType &&
          (!widget.isForWork || micQuality > 0) &&
          (!widget.isForGaming || hasGameMode == 'Sim') &&
          (!widget.isForPhysicalActivity || resistance != 'N/A')) {
        filteredFonesConsolidados.add(fone);
      }
    }

    // Rankeia com base no factor score
    filteredFonesConsolidados.sort((a, b) {
      double scoreA =
          factorScores[averageCluster.indexOf(a)].reduce((a, b) => a + b);
      double scoreB =
          factorScores[averageCluster.indexOf(b)].reduce((a, b) => a + b);
      return scoreB.compareTo(scoreA);
    });

    // Seleciona o top 3 de consolidados
    _filteredFonesBoasApostas = filteredFonesConsolidados.take(3).toList();

    //filtra as apostas
    var filteredFonesBoasApostas = <List<dynamic>>[];
    for (var fone in smallestCluster) {
      double price = double.tryParse(fone[2].toString()) ?? 0;
      String type = fone[1].toString();
      double micQuality = double.tryParse(fone[8].toString()) ?? 0; // microfone
      String hasGameMode = fone[9].toString(); // possui_modo_jogo
      String resistance = fone[10].toString(); // resistencia
      if (price >= widget.minPrice &&
          price <= widget.maxPrice &&
          type == widget.selectedType &&
          (!widget.isForWork || micQuality > 0) &&
          (!widget.isForGaming || hasGameMode == 'Sim') &&
          (!widget.isForPhysicalActivity || resistance != 'N/A')) {
        filteredFonesBoasApostas.add(fone);
      }
    }

    // Rankeia com base no factor score
    filteredFonesBoasApostas.sort((a, b) {
      double scoreA =
          factorScores[smallestCluster.indexOf(a)].reduce((a, b) => a + b);
      double scoreB =
          factorScores[smallestCluster.indexOf(b)].reduce((a, b) => a + b);
      return scoreB.compareTo(scoreA);
    });

    // Seleciona o top 3 de apostas
    _filteredFonesConsolidados = filteredFonesBoasApostas.take(3).toList();

    setState(() {
      _isLoading = false;
    });
  }

  // Abrir URL
  void _launchURL(String url) async {
    Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }

//Lista os Fones
  List<Widget> _buildFoneList(List<List<dynamic>> fones) {
    if (fones.isEmpty) {
      return [
        ListTile(
          title: Text('Nenhum fone encontrado'),
        ),
      ];
    }

    return fones.map((fone) {
      String nome = fone[0].toString();
      double preco = double.tryParse(fone[2].toString()) ?? 0;
      double nota = double.tryParse(fone[3].toString()) ?? 0;
      String link = fone[11].toString();

      return ListTile(
        title: Text(nome),
        subtitle: Text(
            'Preço: R${preco.toStringAsFixed(2)} | Nota: ${nota.toStringAsFixed(1)}'),
        trailing: Icon(Icons.open_in_new),
        onTap: () => _launchURL(link),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Resultados'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Custo Benefício',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ..._buildFoneList(_filteredFonesCustoBeneficio),
                  if (_filteredFonesCustoBeneficio.length < 3)
                    ...List.generate(
                      3 - _filteredFonesCustoBeneficio.length,
                      (index) => ListTile(
                        title: Text('...'),
                      ),
                    ),
                  SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Boas Apostas',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ..._buildFoneList(_filteredFonesBoasApostas),
                  if (_filteredFonesBoasApostas.length < 3)
                    ...List.generate(
                      3 - _filteredFonesBoasApostas.length,
                      (index) => ListTile(
                        title: Text('...'),
                      ),
                    ),
                  SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Consolidados no Mercado',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ..._buildFoneList(_filteredFonesConsolidados),
                  if (_filteredFonesConsolidados.length < 3)
                    ...List.generate(
                      3 - _filteredFonesConsolidados.length,
                      (index) => ListTile(
                        title: Text('...'),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class KMeans {
  //Inicializa os centróides aleatoriamente.
  //Atribui cada ponto de dados ao centróide mais próximo.
  //Recalcula os centróides com base nos pontos atribuídos.
  //Repete até que os centróides não mudem significativamente (convergência).

  final int numClusters;
  final int maxIterations;

  KMeans({required this.numClusters, this.maxIterations = 100});

  _KMeansResult fit(List<List<double>> data) {
    Random random = Random();
    List<List<double>> centroids =
        List.generate(numClusters, (_) => data[random.nextInt(data.length)]);
    List<int> labels = List.filled(data.length, -1);

    for (int iteration = 0; iteration < maxIterations; iteration++) {
      // Classifica baseado no centroido mais próximo
      for (int i = 0; i < data.length; i++) {
        labels[i] = _closestCentroid(data[i], centroids);
      }

      // Calcula novos centroides
      List<List<double>> newCentroids =
          List.generate(numClusters, (_) => List.filled(data[0].length, 0));
      List<int> counts = List.filled(numClusters, 0);

      for (int i = 0; i < data.length; i++) {
        int label = labels[i];
        for (int j = 0; j < data[i].length; j++) {
          newCentroids[label][j] += data[i][j];
        }
        counts[label]++;
      }

      for (int i = 0; i < numClusters; i++) {
        for (int j = 0; j < newCentroids[i].length; j++) {
          newCentroids[i][j] /= counts[i];
        }
      }

      if (_converged(centroids, newCentroids)) {
        break;
      }

      centroids = newCentroids;
    }

    return _KMeansResult(centroids: centroids, clusterIndices: labels);
  }

  int _closestCentroid(List<double> point, List<List<double>> centroids) {
    double minDistance = double.infinity;
    int minIndex = -1;
    for (int i = 0; i < centroids.length; i++) {
      double distance = _euclideanDistance(point, centroids[i]);
      if (distance < minDistance) {
        minDistance = distance;
        minIndex = i;
      }
    }
    return minIndex;
  }

  double _euclideanDistance(List<double> a, List<double> b) {
    double sum = 0;
    for (int i = 0; i < a.length; i++) {
      sum += pow(a[i] - b[i], 2);
    }
    return sqrt(sum);
  }

  bool _converged(
      List<List<double>> centroids, List<List<double>> newCentroids) {
    for (int i = 0; i < centroids.length; i++) {
      if (_euclideanDistance(centroids[i], newCentroids[i]) > 0.001) {
        return false;
      }
    }
    return true;
  }
}

class _KMeansResult {
  final List<List<double>> centroids;
  final List<int> clusterIndices;

  _KMeansResult({required this.centroids, required this.clusterIndices});
}

class PCA {
  final int numComponents;

  PCA({required this.numComponents});

  PCAResult fit(List<List<double>> data) {
    // Performa PCA
    var covarianceMatrix = _calculateCovarianceMatrix(data);
    var eigenvalues = _calculateEigenvalues(covarianceMatrix);
    var eigenvectors = _calculateEigenvectors(covarianceMatrix, eigenvalues);
    var loadings = _calculateLoadings(eigenvectors, eigenvalues);
    var scores = _calculateScores(data, loadings);

    return PCAResult(loadings: loadings, scores: scores);
  }

  List<List<double>> _calculateCovarianceMatrix(List<List<double>> data) {
    // Calcula a significancia de cada variavel
    var means = List.generate(data[0].length, (_) => 0.0);
    for (var row in data) {
      for (int i = 0; i < row.length; i++) {
        means[i] += row[i];
      }
    }
    for (int i = 0; i < means.length; i++) {
      means[i] /= data.length;
    }

    // Calcula a matriz de covariância
    var covarianceMatrix =
        List.generate(data[0].length, (_) => List.filled(data[0].length, 0.0));
    for (var row in data) {
      for (int i = 0; i < row.length; i++) {
        for (int j = 0; j < row.length; j++) {
          covarianceMatrix[i][j] += (row[i] - means[i]) * (row[j] - means[j]);
        }
      }
    }
    for (int i = 0; i < covarianceMatrix.length; i++) {
      for (int j = 0; j < covarianceMatrix[0].length; j++) {
        covarianceMatrix[i][j] /= data.length - 1;
      }
    }

    return covarianceMatrix;
  }

  List<double> _calculateEigenvalues(List<List<double>> covarianceMatrix) {
    // Calcula os autovalores da matriz de covariância
    var eigenvalues = List.generate(covarianceMatrix.length, (_) => 0.0);
    for (int i = 0; i < covarianceMatrix.length; i++) {
      eigenvalues[i] = covarianceMatrix[i][i];
    }

    return eigenvalues;
  }

  List<List<double>> _calculateEigenvectors(
      List<List<double>> covarianceMatrix, List<double> eigenvalues) {
    // Calcula os autovetores da matriz de covariância
    var eigenvectors = List.generate(covarianceMatrix.length,
        (_) => List.filled(covarianceMatrix.length, 0.0));
    for (int i = 0; i < covarianceMatrix.length; i++) {
      eigenvectors[i][i] = 1;
    }

    return eigenvectors;
  }

  List<List<double>> _calculateLoadings(
      List<List<double>> eigenvectors, List<double> eigenvalues) {
    // Calcular a matriz de cargas
    var loadings = List.generate(
        eigenvectors[0].length, (_) => List.filled(eigenvectors.length, 0.0));
    for (int i = 0; i < eigenvectors.length; i++) {
      for (int j = 0; j < eigenvectors[0].length; j++) {
        loadings[j][i] = eigenvectors[i][j] * sqrt(eigenvalues[i]);
      }
    }

    return loadings;
  }

  List<List<double>> _calculateScores(
      List<List<double>> data, List<List<double>> loadings) {
    // Calcula a matriz de scores
    var scores =
        List.generate(data.length, (_) => List.filled(loadings.length, 0.0));
    for (int i = 0; i < data.length; i++) {
      for (int j = 0; j < loadings.length; j++) {
        for (int k = 0; k < data[0].length; k++) {
          scores[i][j] += data[i][k] * loadings[k][j];
        }
      }
    }

    return scores;
  }
}

class PCAResult {
  final List<List<double>> loadings;
  final List<List<double>> scores;

  PCAResult({required this.loadings, required this.scores});
}
