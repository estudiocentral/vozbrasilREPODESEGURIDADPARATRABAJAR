import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:marquee/marquee.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_session/audio_session.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Nuevo paquete para verificar conexión
import 'package:share_plus/share_plus.dart'; // Nuevo paquete para compartir
import 'package:loading_animation_widget/loading_animation_widget.dart'; // Nuevo paquete para el loader
import 'package:flutter_spinkit/flutter_spinkit.dart'; // Nuevo paquete para la animación Ripple


void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  // Inicializar audio en background
  try {
    await Future.wait([
      JustAudioBackground.init(
        androidNotificationChannelId: 'com.kym.lavozdelacuradivina.radio.channel.audio',
        androidNotificationChannelName: 'Radio A Voz da Cura Divina',
        androidNotificationOngoing: false,
        androidShowNotificationBadge: true,
        androidStopForegroundOnPause: true,
        notificationColor: const Color(0xFF2196f3),
      ),
      AudioSession.instance.then((session) =>
          session.configure(const AudioSessionConfiguration.music())
      ),
    ]);
    debugPrint("JustAudioBackground inicializado correctamente");
  } catch (e) {
    debugPrint('Error inicializando JustAudioBackground: $e');
  }


  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A Voz da Cura Divina',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.grey[200],
      ),
      home: const RadioHome(),
    );
  }
}


class RadioHome extends StatefulWidget {
  const RadioHome({Key? key}) : super(key: key);


  @override
  State<RadioHome> createState() => _RadioHomeState();
}


class _RadioHomeState extends State<RadioHome> with WidgetsBindingObserver {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isDarkMode = false; // Nuevo estado para el modo oscuro
  bool _isInitialLoading = true; // Nuevo estado para la carga inicial
  bool _isLoading = false; // Nuevo estado para el cargador
  String _errorMessage = '';
  double _volume = 1.0; // Control de volumen
  bool _isConnectionGood = true; // Estado de la conexión a Internet


  // Constantes constantes
  static const String streamUrl = 'https://s10.maxcast.com.br:9083/live';
  static const String logoAsset = 'assets/iconolavoz.png';


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializePlayer();
    _checkInternetConnection(); // Verificar conexión al iniciar
  }


  Future<void> _initializePlayer() async {
    try {
      await Future.wait([
        _setupPlayerListeners(),
        _initializeAudio(),
      ]);
    } catch (e) {
      debugPrint("Error inicializando el player: $e");
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al inicializar el reproductor: ${e.toString()}';
          _isInitialLoading = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitialLoading = false; // La carga inicial ha terminado
        });
      }
    }
  }


  Future<void> _setupPlayerListeners() async {
    _audioPlayer.processingStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isLoading = state == ProcessingState.buffering; // Actualiza el estado del cargador
        });
      }
      if (state == ProcessingState.completed) {
        _restartStream();
      }
    });
  }


  @override
  void dispose() {
    _audioPlayer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _audioPlayer.playerState.playing &&
        _audioPlayer.processingState == ProcessingState.idle) {
      _restartStream();
    }
  }


  Future<void> _initializeAudio() async {
    if (!mounted) return;


    setState(() {
      _errorMessage = '';
    });


    try {
      final mediaItem = MediaItem(
        id: streamUrl,
        title: 'A Voz da Cura Divina',
        artist: 'Radio',
      );


      await _audioPlayer.setAudioSource(
        AudioSource.uri(
          Uri.parse(streamUrl),
          tag: mediaItem,
        ),
        preload: false,
      );
    } catch (e) {
      debugPrint("Error en la inicialización del audio: $e");
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al inicializar el audio: ${e.toString()}';
        });
      }
    }
  }


  Future<void> _restartStream() async {
    try {
      await checkInternetConnection(); // Verifica la conexión antes de reiniciar
      await _audioPlayer.stop();
      await _initializeAudio();
      if (_audioPlayer.playerState.playing) {
        setState(() { _isLoading = true; }); // Mostrar el inkDrop antes de iniciar la reproducción
        await _audioPlayer.play();
      }
    } catch (e) {
      debugPrint("Error al reiniciar el stream: $e");
    }
  }


  Future<void> _playOrStopStream() async {
    try {
      if (_audioPlayer.playerState.playing) {
        await _audioPlayer.stop();
        setState(() {
          _isLoading = false; // Asegurarse que isLoading se actualiza a false al hacer stop
        });
      } else {
        if (_audioPlayer.processingState == ProcessingState.idle) {
          await _initializeAudio();
        }


        // Mostrar el inkDrop inmediatamente en el hilo principal
        setState(() {
          _isLoading = true;
        });


        await _audioPlayer.play();


        if (_isConnectionGood) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _isLoading = false; // Ocultar InkDrop después de 2 segundos
              });
            }
          });
        }
      }


    } catch (e) {
      debugPrint("Error al reproducir/detener el stream: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;  // Asegurar que el loading se detiene en caso de error
          _errorMessage = 'Error en la reproducción';
        });
      }
    }
  }


  Future<void> _checkInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isConnectionGood = connectivityResult != ConnectivityResult.none;
    });
  }


  Future<void> checkInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      setState(() {
        _errorMessage = 'No hay conexión a Internet. Por favor, verifica tu conexión.';
        _isConnectionGood = false;
      });
    } else {
      setState(() {
        _isConnectionGood = true;
      });
    }
  }


  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      final bool canLaunch = await canLaunchUrl(url);
      if (canLaunch) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
          webViewConfiguration: const WebViewConfiguration(
            enableJavaScript: true,
            enableDomStorage: true,
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo abrir el enlace'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error al abrir URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir el enlace: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }


  Future<void> _shareApp() async {
    await Share.share(
      'Confira a A Voz da Cura Divina no Google Play Store: https://play.google.com/store/apps/details?id=com.kym.lavozdelacuradivina.radio',
      subject: 'Compartilhar A Voz da Cura Divina',
    );
  }


  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String url,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }


  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDarkMode ? const Color(0xFF0A192F) : const Color(0xFF0A192F).withOpacity(0.8),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMenuTile(
                icon: Icons.language,
                title: "Site e Reprise",
                url: "https://igrejaprimitivadoutrinadivina.com/",
                onTap: () => _launchURL("https://igrejaprimitivadoutrinadivina.com/"),
              ),
              _buildMenuTile(
                icon: Icons.notes,
                title: "Pedidos de Oração",
                url: "https://www.igrejaprimitivadoutrinadivina.com/recados",
                onTap: () => _launchURL("https://www.igrejaprimitivadoutrinadivina.com/recados"),
              ),
              _buildMenuTile(
                icon: Icons.location_on,
                title: "Endereços",
                url: "https://igrejaprimitivadoutrinadivina.com/internas/enderecos-ipdd",
                onTap: () => _launchURL("https://igrejaprimitivadoutrinadivina.com/internas/enderecos-ipdd"),
              ),
              _buildMenuTile(
                icon: Icons.volunteer_activism,
                title: "Ajude esta obra missionaria",
                url: "https://www.igrejaprimitivadoutrinadivina.com/internas/contas-bancarias",
                onTap: () => _launchURL("https://www.igrejaprimitivadoutrinadivina.com/internas/contas-bancarias"),
              ),
              _buildMenuTile(
                icon: Icons.share, // Ícono para compartir
                title: "Compartilhar",
                url: "https://play.google.com/store/apps/details?id=com.kym.lavozdelacuradivina.radio",
                onTap: _shareApp,
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: SwitchListTile(
                  key: ValueKey(_isDarkMode),
                  title: const Text(
                    "Modo Escuro",
                    style: TextStyle(color: Colors.white),
                  ),
                  value: _isDarkMode,
                  onChanged: (bool value) {
                    setState(() {
                      _isDarkMode = value;
                    });
                    Navigator.pop(context); // Minimiza el menú al cambiar el modo oscuro
                  },
                  activeColor: const Color(0xFF00FFFF), // Azul cian claro
                  inactiveThumbColor: Colors.grey,
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildSoundWave({
    required double height,
    required double width,
    required Color color,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: width,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LoadingAnimationWidget.inkDrop( // Loader InkDrop
                color: Colors.blue,
                size: 50.0,
              ),
            ],
          ),
        ),
      );
    }


    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage),
              ElevatedButton(
                onPressed: _initializeAudio,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }


    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF0A192F) : Colors.grey[200],
      body: Stack(
        children: [
          if (_isDarkMode)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [ // Degradado invertido en modo oscuro
                      const Color(0xFF1E3A5F).withOpacity(0.8),
                      const Color.fromARGB(255, 2, 21, 46).withOpacity(0.8),
                    ],
                  ),
                ),
              ),
            ),
          if (!_isDarkMode)
            Positioned.fill(
              child: Image.asset(
                'assets/fondovozdacura.png',
                fit: BoxFit.cover,
              ),
            ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'A Voz da Cura Divina',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w300),
                ),
                const SizedBox(height: 10),
                const CircleAvatar(
                  radius: 60,
                  backgroundImage: AssetImage('assets/iconolavoz.png'),
                ),
                const SizedBox(height: 20),
                Container(
                  width: 300,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: _isDarkMode ? const Color.fromARGB(255, 6, 19, 44) : Colors.white, // Color celeste bebé en modo oscuro
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _isDarkMode ? Colors.transparent : const Color.fromARGB(255, 120, 163, 250).withOpacity(0.8), // Azul bebé y sombra más notoria
                        offset: const Offset(0, 10),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 40),
                            child: Row(
                              children: [
                                _buildSoundWave(
                                  height: 40,
                                  width: _audioPlayer.playerState.playing ? 6 : 3,
                                  color: _isDarkMode ? const Color(0xFF00FFFF) : Colors.black,
                                ),
                                _buildSoundWave(
                                  height: 25,
                                  width: _audioPlayer.playerState.playing ? 6 : 3,
                                  color: _isDarkMode ? const Color(0xFF00FFFF) : Colors.black,
                                ),
                                _buildSoundWave(
                                  height: 15,
                                  width: _audioPlayer.playerState.playing ? 6 : 3,
                                  color: _isDarkMode ? const Color(0xFF00FFFF) : Colors.black,
                                ),
                              ],
                            ),
                          ),
                          FloatingActionButton(
                            onPressed: _playOrStopStream,
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            child: Icon(
                              _audioPlayer.playerState.playing ? Icons.stop : Icons.play_arrow,
                              color: _isDarkMode ? const Color(0xFF00FFFF) : Colors.black,
                              size: 40,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 40),
                            child: Row(
                              children: [
                                _buildSoundWave(
                                  height: 15,
                                  width: _audioPlayer.playerState.playing ? 6 : 3,
                                  color: _isDarkMode ? const Color(0xFF00FFFF) : Colors.black,
                                ),
                                _buildSoundWave(
                                  height: 25,
                                  width: _audioPlayer.playerState.playing ? 6 : 3,
                                  color: _isDarkMode ? const Color(0xFF00FFFF) : Colors.black,
                                ),
                                _buildSoundWave(
                                  height: 40,
                                  width: _audioPlayer.playerState.playing ? 6 : 3,
                                  color: _isDarkMode ? const Color(0xFF00FFFF) : Colors.black,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: _audioPlayer.playerState.playing ? 20 : 10),
                      _audioPlayer.playerState.playing
                          ? SizedBox(
                              height: 20,
                              child: Marquee(
                                text: "A Voz Da Cura Divina No Ar - Evangelizando o Mundo",
                                style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
                                scrollAxis: Axis.horizontal,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                blankSpace: 50.0,
                                velocity: 30.0,
                                pauseAfterRound: const Duration(seconds: 1),
                                startPadding: 10.0,
                                accelerationDuration: const Duration(seconds: 1),
                                accelerationCurve: Curves.linear,
                                decelerationDuration: const Duration(milliseconds: 500),
                                decelerationCurve: Curves.easeOut,
                              ),
                            )
                          : Text(
                              "Desligado",
                              style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
                            ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Slider(
                            value: _volume,
                            min: 0.0,
                            max: 1.0,
                            onChanged: (value) {
                              setState(() {
                                _volume = value;
                                _audioPlayer.setVolume(value); // Ajusta el volumen del reproductor
                              });
                            },
                            activeColor: _isDarkMode ? const Color(0xFF00FFFF) : Colors.black,
                            inactiveColor: _isDarkMode ? Colors.grey : Colors.grey[300],
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showMenu(context),
                        icon: Icon(Icons.language, color: _isDarkMode ? Colors.white : Colors.black),
                        label: Text('Website', style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isDarkMode ? const Color(0xFF0A192F) : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: _isDarkMode ? const Color(0xFF00FFFF) : Colors.black),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading) // Mostrar inkDrop solo si _isLoading es true
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: LoadingAnimationWidget.inkDrop(
                  color: Colors.blue,
                  size: 50.0,
                ),
              ),
            ),
          if (!_isLoading && _audioPlayer.playerState.playing) // Mostrar Ripple solo si NO está cargando y está reproduciendo
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: SpinKitRipple(
                  color: Colors.blue,
                  size: 100.0,
                ),
              ),
            ),
        ],
      ),
    );
  }
}


class MenuItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final String url;


  const MenuItem({
    Key? key,
    required this.icon,
    required this.text,
    required this.url,
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(text, style: const TextStyle(color: Colors.white)),
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      },
    );
  }
}
