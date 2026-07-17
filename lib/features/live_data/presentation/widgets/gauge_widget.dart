import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'gauge_painter.dart';

enum ObdMetricType {
  rpm,
  speed,
  coolant,
  voltage,
  throttle,
  engineLoad,
  map,
  fuel,
}

class ObdMetricConfig {
  final ObdMetricType type;
  final String label;
  final String unit;
  final double minValue;
  final double maxValue;
  final double warningThreshold;
  final Color color;

  ObdMetricConfig({
    required this.type,
    required this.label,
    required this.unit,
    required this.minValue,
    required this.maxValue,
    required this.warningThreshold,
    required this.color,
  });

  static List<ObdMetricConfig> get all => [
    ObdMetricConfig(
      type: ObdMetricType.rpm,
      label: 'TACHOMETER',
      unit: 'RPM',
      minValue: 0,
      maxValue: 8000,
      warningThreshold: 6000,
      color: const Color(0xFF00FFCC), // Neon Cyan
    ),
    ObdMetricConfig(
      type: ObdMetricType.speed,
      label: 'SPEEDOMETER',
      unit: 'KM/H',
      minValue: 0,
      maxValue: 220,
      warningThreshold: 110,
      color: const Color(0xFF00E5FF), // Cyber Blue
    ),
    ObdMetricConfig(
      type: ObdMetricType.coolant,
      label: 'WATER TEMP',
      unit: '°C',
      minValue: 50,
      maxValue: 130,
      warningThreshold: 100,
      color: const Color(0xFFFF9900), // Amber Orange
    ),
    ObdMetricConfig(
      type: ObdMetricType.voltage,
      label: 'BATTERY VOLTS',
      unit: 'V',
      minValue: 9,
      maxValue: 16,
      warningThreshold: 11.5, // Note: warning is below this threshold, but for painter simplicity we'll handle standard thresholds
      color: const Color(0xFFD400FF), // Neon Purple
    ),
    ObdMetricConfig(
      type: ObdMetricType.throttle,
      label: 'THROTTLE',
      unit: '%',
      minValue: 0,
      maxValue: 100,
      warningThreshold: 90,
      color: const Color(0xFF33FF33), // Acid Green
    ),
    ObdMetricConfig(
      type: ObdMetricType.engineLoad,
      label: 'ENGINE LOAD',
      unit: '%',
      minValue: 0,
      maxValue: 100,
      warningThreshold: 85,
      color: const Color(0xFFFF007F), // Neon Pink
    ),
    ObdMetricConfig(
      type: ObdMetricType.map,
      label: 'INTAKE MAP',
      unit: 'kPa',
      minValue: 20,
      maxValue: 150,
      warningThreshold: 130,
      color: const Color(0xFFFFD700), // Gold Yellow
    ),
    ObdMetricConfig(
      type: ObdMetricType.fuel,
      label: 'FUEL LEVEL',
      unit: '%',
      minValue: 0,
      maxValue: 100,
      warningThreshold: 15,
      color: const Color(0xFFFFB300), // Amber Yellow
    ),
  ];
}

class GaugeWidget extends StatefulWidget {
  final double value;
  final ObdMetricConfig config;
  final VoidCallback onTap;

  const GaugeWidget({
    super.key,
    required this.value,
    required this.config,
    required this.onTap,
  });

  @override
  State<GaugeWidget> createState() => _GaugeWidgetState();
}
class _GaugeWidgetState extends State<GaugeWidget> with SingleTickerProviderStateMixin {
  double _peakValue = 0.0;
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _peakValue = widget.value;
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _animation = Tween<double>(begin: widget.value, end: widget.value).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant GaugeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.config.type != oldWidget.config.type) {
      _peakValue = widget.value;
      _controller.stop();
      _animation = Tween<double>(begin: widget.value, end: widget.value).animate(_controller);
    } else {
      if (widget.value > _peakValue) {
        _peakValue = widget.value;
      }
      
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.value,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutCubic,
        ),
      );
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final displayValue = _animation.value;
        final isWarning = (widget.config.type == ObdMetricType.fuel ||
                widget.config.type == ObdMetricType.voltage)
            ? displayValue <= widget.config.warningThreshold
            : displayValue >= widget.config.warningThreshold;

        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isWarning 
                    ? const Color(0xFFFF3366).withOpacity(0.3) 
                    : widget.config.color.withOpacity(0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isWarning 
                      ? const Color(0xFFFF3366).withOpacity(0.05) 
                      : widget.config.color.withOpacity(0.02),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Bar showing Peak Info & Dynamic Warn indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: widget.config.color.withOpacity(0.3), width: 0.5),
                      ),
                      child: Text(
                        'PEAK: ${_peakValue.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: widget.config.color.withOpacity(0.8),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    if (isWarning)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3366).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Color(0xFFFF3366), size: 10),
                            SizedBox(width: 2),
                            Text(
                              'LIMIT',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF3366),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Futuristic Segmented Gauge Outer Frame
                SizedBox(
                  width: 180,
                  height: 180,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(180, 180),
                        painter: GaugePainter(
                          value: displayValue,
                          minValue: widget.config.minValue,
                          maxValue: widget.config.maxValue,
                          activeColor: widget.config.color,
                          backgroundColor: AppColors.surface,
                          warningThreshold: widget.config.warningThreshold,
                        ),
                      ),
                      // Center Digital Readout
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 12),
                          Text(
                            displayValue.toStringAsFixed(widget.config.type == ObdMetricType.voltage ? 1 : 0),
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: isWarning ? const Color(0xFFFF3366) : Colors.white,
                              fontFamily: 'monospace',
                              shadows: [
                                Shadow(
                                  color: isWarning 
                                      ? const Color(0xFFFF3366).withOpacity(0.6) 
                                      : widget.config.color.withOpacity(0.4),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            widget.config.unit,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: widget.config.color.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Label showing metric name & tap instruction
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.config.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.swap_horizontal_circle_outlined, size: 12, color: widget.config.color.withOpacity(0.5)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
