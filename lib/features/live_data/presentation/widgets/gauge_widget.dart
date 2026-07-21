import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/performance_utils.dart';
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
  fuelEconomy,
  intakeAirTemp,
  maf,
  timingAdvance,
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
      label: 'Putaran Mesin',
      unit: 'RPM',
      minValue: 0,
      maxValue: 8000,
      warningThreshold: 6000,
      color: const Color(0xFF00FFCC),
    ),
    ObdMetricConfig(
      type: ObdMetricType.speed,
      label: 'Kecepatan',
      unit: 'km/h',
      minValue: 0,
      maxValue: 220,
      warningThreshold: 110,
      color: const Color(0xFF00E5FF),
    ),
    ObdMetricConfig(
      type: ObdMetricType.coolant,
      label: 'Suhu Pendingin',
      unit: '°C',
      minValue: 50,
      maxValue: 130,
      warningThreshold: 100,
      color: const Color(0xFFFF9900),
    ),
    ObdMetricConfig(
      type: ObdMetricType.voltage,
      label: 'Tegangan Aki',
      unit: 'V',
      minValue: 9,
      maxValue: 16,
      warningThreshold: 11.5,
      color: const Color(0xFFD400FF),
    ),
    ObdMetricConfig(
      type: ObdMetricType.throttle,
      label: 'Bukaan Gas',
      unit: '%',
      minValue: 0,
      maxValue: 100,
      warningThreshold: 90,
      color: const Color(0xFF33FF33),
    ),
    ObdMetricConfig(
      type: ObdMetricType.engineLoad,
      label: 'Beban Mesin',
      unit: '%',
      minValue: 0,
      maxValue: 100,
      warningThreshold: 85,
      color: const Color(0xFFFF007F),
    ),
    ObdMetricConfig(
      type: ObdMetricType.map,
      label: 'Tekanan Intake',
      unit: 'kPa',
      minValue: 20,
      maxValue: 150,
      warningThreshold: 130,
      color: const Color(0xFFFFD700),
    ),
    ObdMetricConfig(
      type: ObdMetricType.fuel,
      label: 'Level BBM',
      unit: '%',
      minValue: 0,
      maxValue: 100,
      warningThreshold: 15,
      color: const Color(0xFFFFB300),
    ),
    ObdMetricConfig(
      type: ObdMetricType.fuelEconomy,
      label: 'Konsumsi BBM',
      unit: 'km/L',
      minValue: 0,
      maxValue: 30,
      warningThreshold: 5,
      color: const Color(0xFF00FF66),
    ),
    ObdMetricConfig(
      type: ObdMetricType.intakeAirTemp,
      label: 'Suhu Intake',
      unit: '°C',
      minValue: -20,
      maxValue: 100,
      warningThreshold: 70,
      color: const Color(0xFF4FC3F7),
    ),
    ObdMetricConfig(
      type: ObdMetricType.maf,
      label: 'Aliran Udara',
      unit: 'g/s',
      minValue: 0,
      maxValue: 200,
      warningThreshold: 150,
      color: const Color(0xFF80CBC4),
    ),
    ObdMetricConfig(
      type: ObdMetricType.timingAdvance,
      label: 'Timing Advance',
      unit: '°',
      minValue: -30,
      maxValue: 60,
      warningThreshold: 45,
      color: const Color(0xFFFFEE58),
    ),
  ];
}

class GaugeWidget extends StatefulWidget {
  final double? value;
  final ObdMetricConfig config;
  final VoidCallback onTap;
  final bool compact;

  const GaugeWidget({
    super.key,
    required this.value,
    required this.config,
    required this.onTap,
    this.compact = false,
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
    _peakValue = widget.value ?? 0.0;
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _animation = Tween<double>(begin: widget.value ?? 0.0, end: widget.value ?? 0.0).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant GaugeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentValue = widget.value ?? 0.0;
    if (widget.config.type != oldWidget.config.type) {
      _peakValue = currentValue;
      _controller.stop();
      _animation = Tween<double>(begin: currentValue, end: currentValue).animate(_controller);
    } else {
      if (widget.value != null && currentValue > _peakValue) {
        _peakValue = currentValue;
      }

      final previousDisplayed = _animation.value;
      final shouldAnimate = shouldAnimateGaugeValue(
        previous: previousDisplayed,
        next: currentValue,
        minValue: widget.config.minValue,
        maxValue: widget.config.maxValue,
      );

      if (!shouldAnimate) {
        _animation = Tween<double>(begin: currentValue, end: currentValue).animate(_controller);
        return;
      }

      _animation = Tween<double>(
        begin: previousDisplayed,
        end: currentValue,
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
        final isWarning = widget.value == null
            ? false
            : (widget.config.type == ObdMetricType.fuel ||
                    widget.config.type == ObdMetricType.voltage)
                ? displayValue <= widget.config.warningThreshold
                : displayValue >= widget.config.warningThreshold;

        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: double.infinity,
            padding: widget.compact 
                ? const EdgeInsets.symmetric(vertical: 6, horizontal: 10) 
                : const EdgeInsets.all(12),
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
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
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
                          widget.value == null
                              ? 'Puncak: --'
                              : 'Puncak: ${_peakValue.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: widget.config.color.withOpacity(0.8),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      if (isWarning) ...[
                        const SizedBox(width: 8),
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
                                'BATAS',
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
                    ],
                  ),
                ),
                SizedBox(height: widget.compact ? 4 : 8),
                // Futuristic Segmented Gauge Outer Frame
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: widget.compact ? 135 : 180,
                    height: widget.compact ? 135 : 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        RepaintBoundary(
                          child: CustomPaint(
                            size: Size(
                              widget.compact ? 135 : 180,
                              widget.compact ? 135 : 180,
                            ),
                            painter: GaugePainter(
                              value: displayValue,
                              minValue: widget.config.minValue,
                              maxValue: widget.config.maxValue,
                              activeColor: widget.config.color,
                              backgroundColor: AppColors.surface,
                              warningThreshold: widget.config.warningThreshold,
                            ),
                          ),
                        ),
                        // Center Digital Readout
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(height: widget.compact ? 6 : 12),
                            Text(
                              widget.value == null
                                  ? '--'
                                  : displayValue.toStringAsFixed(widget.config.type == ObdMetricType.voltage ? 1 : 0),
                              style: TextStyle(
                                fontSize: widget.compact ? 30 : 38,
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
                                fontSize: widget.compact ? 10 : 12,
                                fontWeight: FontWeight.bold,
                                color: widget.config.color.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: widget.compact ? 4 : 8),
                // Label showing metric name & tap instruction
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
