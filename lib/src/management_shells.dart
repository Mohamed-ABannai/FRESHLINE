part of 'app.dart';

enum _SalonFinanceRangeFilter { day, week, month, year }

enum _ManagementOrderSearchField { phone, invoice }

enum _ManagementWorkspaceViewFilter { all, productOrders, appointments }

extension _SalonFinanceRangeFilterLabel on _SalonFinanceRangeFilter {
  String get label {
    switch (this) {
      case _SalonFinanceRangeFilter.day:
        return 'Day';
      case _SalonFinanceRangeFilter.week:
        return 'Week';
      case _SalonFinanceRangeFilter.month:
        return 'Month';
      case _SalonFinanceRangeFilter.year:
        return 'Year';
    }
  }
}

extension _ManagementOrderSearchFieldLabel on _ManagementOrderSearchField {
  String get label {
    switch (this) {
      case _ManagementOrderSearchField.phone:
        return 'Phone';
      case _ManagementOrderSearchField.invoice:
        return 'Invoice';
    }
  }
}

extension _ManagementWorkspaceViewFilterLabel
    on _ManagementWorkspaceViewFilter {
  String get label {
    switch (this) {
      case _ManagementWorkspaceViewFilter.all:
        return 'All';
      case _ManagementWorkspaceViewFilter.productOrders:
        return 'Products';
      case _ManagementWorkspaceViewFilter.appointments:
        return 'Appointments';
    }
  }
}

const double _minTextScaleFactor = 0.85;
const double _maxTextScaleFactor = 1.25;

double _normalizeTextScaleFactor(double value) {
  return value.clamp(_minTextScaleFactor, _maxTextScaleFactor).toDouble();
}

class _AppearanceTextScaleControl extends StatelessWidget {
  const _AppearanceTextScaleControl({
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final double normalizedValue = _normalizeTextScaleFactor(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _tr(context, 'Font Size', 'حجم الخط'),
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '${(normalizedValue * 100).round()}%',
              style: TextStyle(
                color: AppPalette.mutedForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider.adaptive(
          value: normalizedValue,
          min: _minTextScaleFactor,
          max: _maxTextScaleFactor,
          divisions: 8,
          label: '${(normalizedValue * 100).round()}%',
          onChanged: onChanged,
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _tr(context, 'Smaller', 'أصغر'),
                style: TextStyle(
                  fontSize: 12,
                  color: AppPalette.mutedForeground,
                ),
              ),
            ),
            Expanded(
              child: Text(
                _tr(context, 'Default', 'افتراضي'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppPalette.mutedForeground,
                ),
              ),
            ),
            Expanded(
              child: Text(
                _tr(context, 'Larger', 'أكبر'),
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 12,
                  color: AppPalette.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Future<void> showAppearanceSettingsSheet({
  required BuildContext context,
  required bool isDarkMode,
  required ValueChanged<bool> onThemeChanged,
  required bool isHighContrast,
  required ValueChanged<bool> onHighContrastChanged,
  required double textScaleFactor,
  required ValueChanged<double> onTextScaleChanged,
  required String selectedLanguage,
  required ValueChanged<String> onLanguageChanged,
  String title = 'Appearance & Language',
  String? subtitle,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => AppearanceSettingsScreen(
        title: title,
        subtitle: subtitle,
        isDarkMode: isDarkMode,
        onThemeChanged: onThemeChanged,
        isHighContrast: isHighContrast,
        onHighContrastChanged: onHighContrastChanged,
        textScaleFactor: textScaleFactor,
        onTextScaleChanged: onTextScaleChanged,
        selectedLanguage: selectedLanguage,
        onLanguageChanged: onLanguageChanged,
      ),
    ),
  );
}

class AppearanceSettingsScreen extends StatefulWidget {
  const AppearanceSettingsScreen({
    super.key,
    required this.title,
    this.subtitle,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.isHighContrast,
    required this.onHighContrastChanged,
    required this.textScaleFactor,
    required this.onTextScaleChanged,
    required this.selectedLanguage,
    required this.onLanguageChanged,
  });

  final String title;
  final String? subtitle;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final bool isHighContrast;
  final ValueChanged<bool> onHighContrastChanged;
  final double textScaleFactor;
  final ValueChanged<double> onTextScaleChanged;
  final String selectedLanguage;
  final ValueChanged<String> onLanguageChanged;

  @override
  State<AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<AppearanceSettingsScreen> {
  late bool _isDarkMode = widget.isDarkMode;
  late bool _isHighContrast = widget.isHighContrast;
  late double _textScaleFactor = _normalizeTextScaleFactor(
    widget.textScaleFactor,
  );
  late String _selectedLanguage = widget.selectedLanguage;

  @override
  Widget build(BuildContext context) {
    final String subtitle = (widget.subtitle ?? '').trim();
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title == 'Appearance & Language'
                ? _tr(context, 'Appearance & Language', 'المظهر واللغة')
                : widget.title,
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: <Widget>[
              if (subtitle.isNotEmpty) ...<Widget>[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: appCardDecoration(),
                  child: Text(
                    subtitle,
                    style: TextStyle(color: AppPalette.mutedForeground),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.all(18),
                decoration: appCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SwitchListTile.adaptive(
                      value: _isDarkMode,
                      onChanged: (bool value) {
                        setState(() => _isDarkMode = value);
                        widget.onThemeChanged(value);
                      },
                      title: Text(_tr(context, 'Dark Mode', 'الوضع الداكن')),
                      subtitle: Text(
                        _isDarkMode
                            ? _tr(
                                context,
                                'Dark appearance is enabled',
                                'تم تفعيل المظهر الداكن',
                              )
                            : _tr(
                                context,
                                'Light appearance is enabled',
                                'تم تفعيل المظهر الفاتح',
                              ),
                        style: TextStyle(color: AppPalette.mutedForeground),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const Divider(height: 22),
                    SwitchListTile.adaptive(
                      value: _isHighContrast,
                      onChanged: (bool value) {
                        setState(() => _isHighContrast = value);
                        widget.onHighContrastChanged(value);
                      },
                      title: Text(_tr(context, 'High Contrast', 'تباين عالٍ')),
                      subtitle: Text(
                        _isHighContrast
                            ? _tr(
                                context,
                                'Stronger contrast is enabled',
                                'تم تفعيل التباين العالي',
                              )
                            : _tr(
                                context,
                                'Use the current default contrast',
                                'استخدم التباين الافتراضي الحالي',
                              ),
                        style: TextStyle(color: AppPalette.mutedForeground),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const Divider(height: 22),
                    _AppearanceTextScaleControl(
                      value: _textScaleFactor,
                      onChanged: (double value) {
                        final double nextValue = _normalizeTextScaleFactor(
                          value,
                        );
                        setState(() => _textScaleFactor = nextValue);
                        widget.onTextScaleChanged(nextValue);
                      },
                    ),
                    const Divider(height: 22),
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>(_selectedLanguage),
                      initialValue: _selectedLanguage,
                      decoration: InputDecoration(
                        labelText: _tr(context, 'Language', 'اللغة'),
                      ),
                      items: <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: 'EN',
                          child: Text(_tr(context, 'English', 'الإنجليزية')),
                        ),
                        DropdownMenuItem<String>(
                          value: 'AR',
                          child: Text(_tr(context, 'Arabic', 'العربية')),
                        ),
                      ],
                      onChanged: (String? value) {
                        if (value == null) {
                          return;
                        }
                        setState(() => _selectedLanguage = value);
                        widget.onLanguageChanged(value);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SalonFinanceDateRange {
  const _SalonFinanceDateRange({
    required this.filter,
    required this.label,
    required this.start,
    required this.end,
    required this.comparisonLabel,
    required this.previousStart,
    required this.previousEnd,
  });

  final _SalonFinanceRangeFilter filter;
  final String label;
  final DateTime start;
  final DateTime end;
  final String comparisonLabel;
  final DateTime previousStart;
  final DateTime previousEnd;

  int get dayCount => end.difference(start).inDays + 1;
}

class _FinanceShareSlice {
  const _FinanceShareSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

class SalonFinanceDetailsScreen extends StatefulWidget {
  const SalonFinanceDetailsScreen({
    super.key,
    required this.user,
    required this.workspace,
    required this.platformRepository,
  });

  final AppUser user;
  final SalonWorkspaceSnapshot workspace;
  final PlatformRepository platformRepository;

  @override
  State<SalonFinanceDetailsScreen> createState() =>
      _SalonFinanceDetailsScreenState();
}

class _SalonFinanceDetailsScreenState extends State<SalonFinanceDetailsScreen> {
  late final SalonSubscriptionStatus? _subscriptionStatus =
      widget.workspace.subscriptionStatus;
  _SalonFinanceRangeFilter _selectedRange = _SalonFinanceRangeFilter.month;

  static DateTime _dayOnly(DateTime value) {
    final DateTime local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  bool _isCompletedBooking(UserOrder order) {
    return order.statusLabel.trim().toLowerCase() == 'completed';
  }

  bool _isCancelledBooking(UserOrder order) {
    return order.statusLabel.trim().toLowerCase() == 'cancelled';
  }

  bool _isRevenueProductOrder(UserOrder order) {
    final String status = order.statusLabel.trim().toLowerCase();
    return status != 'failed' && status != 'refunded' && status != 'cancelled';
  }

  _SalonFinanceDateRange _selectedDateRange() {
    final DateTime today = _dayOnly(DateTime.now());
    switch (_selectedRange) {
      case _SalonFinanceRangeFilter.day:
        return _SalonFinanceDateRange(
          filter: _selectedRange,
          label: 'Today',
          start: today,
          end: today,
          comparisonLabel: 'previous day',
          previousStart: today.subtract(const Duration(days: 1)),
          previousEnd: today.subtract(const Duration(days: 1)),
        );
      case _SalonFinanceRangeFilter.week:
        final DateTime start = today.subtract(const Duration(days: 6));
        return _SalonFinanceDateRange(
          filter: _selectedRange,
          label: 'Last 7 days',
          start: start,
          end: today,
          comparisonLabel: 'previous 7 days',
          previousStart: start.subtract(const Duration(days: 7)),
          previousEnd: start.subtract(const Duration(days: 1)),
        );
      case _SalonFinanceRangeFilter.month:
        final DateTime start = today.subtract(const Duration(days: 29));
        return _SalonFinanceDateRange(
          filter: _selectedRange,
          label: 'Last 30 days',
          start: start,
          end: today,
          comparisonLabel: 'previous 30 days',
          previousStart: start.subtract(const Duration(days: 30)),
          previousEnd: start.subtract(const Duration(days: 1)),
        );
      case _SalonFinanceRangeFilter.year:
        final DateTime start = today.subtract(const Duration(days: 364));
        return _SalonFinanceDateRange(
          filter: _selectedRange,
          label: 'Last 365 days',
          start: start,
          end: today,
          comparisonLabel: 'previous 365 days',
          previousStart: start.subtract(const Duration(days: 365)),
          previousEnd: start.subtract(const Duration(days: 1)),
        );
    }
  }

  List<UserOrder> _ordersWithinRange(
    List<UserOrder> orders,
    DateTime start,
    DateTime end,
  ) {
    return orders
        .where((UserOrder order) {
          final DateTime orderDay = _dayOnly(order.scheduledAt);
          return !orderDay.isBefore(start) && !orderDay.isAfter(end);
        })
        .toList(growable: false);
  }

  List<EmployeeSalaryPayment> _salaryPaymentsWithinRange(
    DateTime start,
    DateTime end,
  ) {
    return widget.workspace.salaryPayments
        .where((EmployeeSalaryPayment payment) {
          final DateTime confirmedDay = _dayOnly(payment.confirmedAt);
          return !confirmedDay.isBefore(start) && !confirmedDay.isAfter(end);
        })
        .toList(growable: false);
  }

  double _subscriptionCostForRange(_SalonFinanceDateRange range) {
    final SalonSubscriptionStatus? status = _subscriptionStatus;
    if (status == null) {
      return 0;
    }
    switch (range.filter) {
      case _SalonFinanceRangeFilter.day:
        return status.cycle == SubscriptionCycleOption.yearly
            ? status.amount / 365
            : status.amount / 30;
      case _SalonFinanceRangeFilter.week:
        return status.cycle == SubscriptionCycleOption.yearly
            ? (status.amount / 365) * 7
            : (status.amount / 30) * 7;
      case _SalonFinanceRangeFilter.month:
        return status.cycle == SubscriptionCycleOption.yearly
            ? status.amount / 12
            : status.amount;
      case _SalonFinanceRangeFilter.year:
        return status.cycle == SubscriptionCycleOption.yearly
            ? status.amount
            : status.amount * 12;
    }
  }

  SalonFinanceSnapshot _financeForRange(_SalonFinanceDateRange range) {
    final List<UserOrder> bookings =
        _ordersWithinRange(widget.workspace.bookings, range.start, range.end)
            .where((UserOrder order) => !_isCancelledBooking(order))
            .toList(growable: false);
    final List<UserOrder> productOrders = _ordersWithinRange(
      widget.workspace.productOrders,
      range.start,
      range.end,
    ).where(_isRevenueProductOrder).toList(growable: false);
    final List<EmployeeSalaryPayment> salaryPayments =
        _salaryPaymentsWithinRange(range.start, range.end);
    final double bookingRevenue = bookings.fold<double>(
      0,
      (double sum, UserOrder order) => sum + order.total.toDouble(),
    );
    final double productRevenue = productOrders.fold<double>(
      0,
      (double sum, UserOrder order) => sum + order.total.toDouble(),
    );
    final int completedBookings = bookings.where(_isCompletedBooking).length;
    final int upcomingBookings = bookings.length - completedBookings;
    final double subscriptionCost = _subscriptionCostForRange(range);
    final double salaryCost = salaryPayments.fold<double>(
      0,
      (double sum, EmployeeSalaryPayment payment) => sum + payment.amount,
    );
    return SalonFinanceSnapshot(
      bookingRevenue: bookingRevenue,
      productRevenue: productRevenue,
      subscriptionCost: subscriptionCost,
      salaryCost: salaryCost,
      bookingProfit:
          bookingRevenue + productRevenue - salaryCost - subscriptionCost,
      completedBookings: completedBookings,
      upcomingBookings: upcomingBookings,
    );
  }

  List<_FinanceShareSlice> _buildShareSlices(
    SalonFinanceSnapshot finance,
    double operatingProfit,
  ) {
    final List<_FinanceShareSlice> slices = <_FinanceShareSlice>[
      if (finance.bookingRevenue > 0)
        _FinanceShareSlice(
          label: 'Service revenue',
          value: finance.bookingRevenue,
          color: AppPalette.primary,
        ),
      if (finance.productRevenue > 0)
        _FinanceShareSlice(
          label: 'Product revenue',
          value: finance.productRevenue,
          color: AppPalette.secondary,
        ),
      if (finance.salaryCost > 0)
        const _FinanceShareSlice(
          label: 'Confirmed salaries',
          value: 0,
          color: Color(0xFFD97706),
        ),
      if (finance.subscriptionCost > 0)
        const _FinanceShareSlice(
          label: 'Subscription cost',
          value: 0,
          color: Color(0xFF64748B),
        ),
    ];
    if (finance.salaryCost > 0) {
      slices[slices.indexWhere(
        (_FinanceShareSlice item) => item.label == 'Confirmed salaries',
      )] = _FinanceShareSlice(
        label: 'Confirmed salaries',
        value: finance.salaryCost,
        color: const Color(0xFFD97706),
      );
    }
    if (finance.subscriptionCost > 0) {
      slices[slices.indexWhere(
        (_FinanceShareSlice item) => item.label == 'Subscription cost',
      )] = _FinanceShareSlice(
        label: 'Subscription cost',
        value: finance.subscriptionCost,
        color: const Color(0xFF64748B),
      );
    }
    if (operatingProfit.abs() > 0) {
      slices.add(
        _FinanceShareSlice(
          label: operatingProfit >= 0 ? 'Operating profit' : 'Operating loss',
          value: operatingProfit.abs(),
          color: operatingProfit >= 0
              ? AppPalette.success
              : const Color(0xFFB42318),
        ),
      );
    }
    return slices;
  }

  String _signedBhd(double value) {
    final String prefix = value >= 0 ? '+' : '-';
    return '$prefix${formatBhd(value.abs())}';
  }

  String _signedCount(int value) {
    return value >= 0 ? '+$value' : '$value';
  }

  @override
  Widget build(BuildContext context) {
    final _SalonFinanceDateRange dateRange = _selectedDateRange();
    final SalonFinanceSnapshot finance = _financeForRange(dateRange);
    final SalonFinanceSnapshot previousFinance = _financeForRange(
      _SalonFinanceDateRange(
        filter: dateRange.filter,
        label: dateRange.comparisonLabel,
        start: dateRange.previousStart,
        end: dateRange.previousEnd,
        comparisonLabel: '',
        previousStart: dateRange.previousStart,
        previousEnd: dateRange.previousEnd,
      ),
    );
    final double operatingProfit = finance.bookingProfit;
    final double previousOperatingProfit = previousFinance.bookingProfit;
    final int currentBookingCount =
        finance.completedBookings + finance.upcomingBookings;
    final int previousBookingCount =
        previousFinance.completedBookings + previousFinance.upcomingBookings;
    final int currentProductOrderCount = _ordersWithinRange(
      widget.workspace.productOrders,
      dateRange.start,
      dateRange.end,
    ).length;
    final int previousProductOrderCount = _ordersWithinRange(
      widget.workspace.productOrders,
      dateRange.previousStart,
      dateRange.previousEnd,
    ).length;
    final int confirmedSalaryCount = _salaryPaymentsWithinRange(
      dateRange.start,
      dateRange.end,
    ).length;
    final List<Employee> salariedEmployees =
        List<Employee>.from(widget.workspace.employees)..sort(
          (Employee a, Employee b) =>
              b.monthlySalary.compareTo(a.monthlySalary),
        );
    final List<_FinanceShareSlice> shareSlices = _buildShareSlices(
      finance,
      operatingProfit,
    );

    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: const Text('Revenue & Profit')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.workspace.salon.localizedName(context),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This view uses real salon bookings, real product orders, and only confirmed employee salaries. The chart updates when you switch between day, week, month, and year.',
                    style: TextStyle(
                      height: 1.45,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Market Share View',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Revenue and cost mix for ${dateRange.label.toLowerCase()}.',
                    style: TextStyle(
                      height: 1.45,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FinanceShareChart(
                    slices: shareSlices,
                    centerLabel: dateRange.label,
                    centerValue: formatBhd(finance.totalRevenue),
                  ),
                  if (shareSlices.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 18),
                    ...shareSlices.map((_FinanceShareSlice slice) {
                      final double totalShare = shareSlices.fold<double>(
                        0,
                        (double sum, _FinanceShareSlice item) =>
                            sum + item.value.abs(),
                      );
                      final double percentage = totalShare <= 0
                          ? 0
                          : (slice.value.abs() / totalShare) * 100;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _FinanceLegendRow(
                          slice: slice,
                          percentage: percentage,
                        ),
                      );
                    }),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'No finance activity was recorded for this period yet.',
                        style: TextStyle(color: AppPalette.mutedForeground),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Filter Period',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _SalonFinanceRangeFilter.values
                        .map((_SalonFinanceRangeFilter range) {
                          return ChoiceChip(
                            label: Text(range.label),
                            selected: _selectedRange == range,
                            selectedColor: AppPalette.primary.withValues(
                              alpha: 0.16,
                            ),
                            side: BorderSide(
                              color: _selectedRange == range
                                  ? AppPalette.primary
                                  : AppPalette.border,
                            ),
                            onSelected: (_) {
                              setState(() => _selectedRange = range);
                            },
                          );
                        })
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: appCardDecoration(
                      color: AppPalette.background,
                      radius: 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${dateRange.label} vs ${dateRange.comparisonLabel}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        _SummaryRow(
                          label: 'Revenue change',
                          value: _signedBhd(
                            finance.totalRevenue - previousFinance.totalRevenue,
                          ),
                        ),
                        _SummaryRow(
                          label: 'Operating profit change',
                          value: _signedBhd(
                            operatingProfit - previousOperatingProfit,
                          ),
                        ),
                        _SummaryRow(
                          label: 'Product order change',
                          value: _signedCount(
                            currentProductOrderCount -
                                previousProductOrderCount,
                          ),
                        ),
                        _SummaryRow(
                          label: 'Booking change',
                          value: _signedCount(
                            currentBookingCount - previousBookingCount,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                children: <Widget>[
                  _SummaryRow(
                    label: 'Total revenue',
                    value: formatBhd(finance.totalRevenue),
                  ),
                  _SummaryRow(
                    label: 'Booking revenue',
                    value: formatBhd(finance.bookingRevenue),
                  ),
                  _SummaryRow(
                    label: 'Product revenue',
                    value: formatBhd(finance.productRevenue),
                  ),
                  _SummaryRow(
                    label: 'Estimated subscription cost',
                    value: formatBhd(finance.subscriptionCost),
                  ),
                  _SummaryRow(
                    label: 'Confirmed salary cost',
                    value: formatBhd(finance.salaryCost),
                  ),
                  const Divider(height: 26),
                  _SummaryRow(
                    label: 'Operating profit',
                    value: formatBhd(operatingProfit),
                    prominent: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _MetricCard(
                      label: 'Product orders',
                      value: '$currentProductOrderCount',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      label: 'Bookings',
                      value: '$currentBookingCount',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      label: 'Salary confirms',
                      value: '$confirmedSalaryCount',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Salary Confirmations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Employee salary cost only appears after the salon owner confirms that month for the employee.',
                    style: TextStyle(
                      height: 1.45,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (salariedEmployees.isEmpty)
                    Text(
                      'No employees yet.',
                      style: TextStyle(color: AppPalette.mutedForeground),
                    )
                  else
                    ...salariedEmployees.map((Employee employee) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: appCardDecoration(
                            color: AppPalette.background,
                            radius: 20,
                          ),
                          child: Row(
                            children: <Widget>[
                              _ManagementAvatar(
                                imagePath: employee.imagePath,
                                radius: 22,
                                icon: Icons.badge_rounded,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      employee.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      employee.role,
                                      style: TextStyle(
                                        color: AppPalette.mutedForeground,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      employee.isSalaryReceivedForMonth()
                                          ? 'Current month confirmed'
                                          : 'Current month pending confirmation',
                                      style: TextStyle(
                                        color:
                                            employee.isSalaryReceivedForMonth()
                                            ? AppPalette.success
                                            : AppPalette.mutedForeground,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: <Widget>[
                                  Text(
                                    formatBhd(employee.monthlySalary),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (employee.salaryLastPaidAt != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        formatCalendarDate(
                                          employee.salaryLastPaidAt!,
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppPalette.mutedForeground,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceShareChart extends StatelessWidget {
  const _FinanceShareChart({
    required this.slices,
    required this.centerLabel,
    required this.centerValue,
  });

  final List<_FinanceShareSlice> slices;
  final String centerLabel;
  final String centerValue;

  @override
  Widget build(BuildContext context) {
    final double total = slices.fold<double>(
      0,
      (double sum, _FinanceShareSlice slice) => sum + slice.value.abs(),
    );
    if (total <= 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: appCardDecoration(color: AppPalette.background, radius: 22),
        child: Text(
          'No activity to chart for this period.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppPalette.mutedForeground),
        ),
      );
    }

    return Center(
      child: SizedBox(
        width: 220,
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            CustomPaint(
              size: const Size.square(220),
              painter: _FinanceShareChartPainter(slices: slices),
            ),
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppPalette.background,
                shape: BoxShape.circle,
                border: Border.all(color: AppPalette.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    centerLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      centerValue,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceShareChartPainter extends CustomPainter {
  _FinanceShareChartPainter({required this.slices});

  final List<_FinanceShareSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final double total = slices.fold<double>(
      0,
      (double sum, _FinanceShareSlice slice) => sum + slice.value.abs(),
    );
    if (total <= 0) {
      return;
    }

    final Rect rect = Rect.fromLTWH(16, 16, size.width - 32, size.height - 32);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..strokeCap = StrokeCap.round;
    const double gapAngle = 0.06;
    final double usableSweep =
        (math.pi * 2) - (gapAngle * math.max(0, slices.length));
    double startAngle = -math.pi / 2;

    for (final _FinanceShareSlice slice in slices) {
      final double sweepAngle = usableSweep * (slice.value.abs() / total);
      paint.color = slice.color;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _FinanceShareChartPainter oldDelegate) {
    return oldDelegate.slices != slices;
  }
}

class _FinanceLegendRow extends StatelessWidget {
  const _FinanceLegendRow({required this.slice, required this.percentage});

  final _FinanceShareSlice slice;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: slice.color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            slice.label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          '${percentage.toStringAsFixed(0)}%',
          style: TextStyle(color: AppPalette.mutedForeground),
        ),
        const SizedBox(width: 12),
        Text(
          formatBhd(slice.value),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class SalonOwnerSubscriptionScreen extends StatefulWidget {
  const SalonOwnerSubscriptionScreen({
    super.key,
    required this.user,
    required this.workspace,
    required this.platformRepository,
  });

  final AppUser user;
  final SalonWorkspaceSnapshot workspace;
  final PlatformRepository platformRepository;

  @override
  State<SalonOwnerSubscriptionScreen> createState() =>
      _SalonOwnerSubscriptionScreenState();
}

class _SalonOwnerSubscriptionScreenState
    extends State<SalonOwnerSubscriptionScreen> {
  late SalonSubscriptionStatus? _subscriptionStatus =
      widget.workspace.subscriptionStatus;
  bool _isActivatingSubscription = false;
  bool _isUpdatingAutoRenew = false;

  static DateTime _dayOnly(DateTime value) {
    final DateTime local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  bool _hasActiveSubscription(SalonSubscriptionStatus? status) {
    if (status == null) {
      return false;
    }
    if (status.expiresAt == null) {
      return true;
    }
    return !_dayOnly(status.expiresAt!).isBefore(_dayOnly(DateTime.now()));
  }

  String _subscriptionStatusLabel(SalonSubscriptionStatus? status) {
    if (status == null) {
      return _tr(
        context,
        'No active salon subscription right now. Choose a monthly or yearly plan when you are ready.',
        'لا يوجد اشتراك صالون فعال حالياً. اختر خطة شهرية أو سنوية عندما تكون جاهزاً.',
      );
    }
    if (status.expiresAt == null) {
      return _tr(
        context,
        '${status.cycle.localizedLabel(context)} plan is active. Expiry date will appear after activation. Auto-renew is ${status.autoRenew ? 'enabled' : 'disabled'}.',
        'خطة ${status.cycle.localizedLabel(context)} مفعلة. سيظهر تاريخ الانتهاء بعد التفعيل. التجديد التلقائي ${status.autoRenew ? 'مفعل' : 'موقوف'}.',
      );
    }
    if (_hasActiveSubscription(status)) {
      return _tr(
        context,
        '${status.cycle.localizedLabel(context)} plan is active until ${formatCalendarDate(status.expiresAt!)}. Auto-renew is ${status.autoRenew ? 'enabled' : 'disabled'}.',
        'خطة ${status.cycle.localizedLabel(context)} مفعلة حتى ${formatCalendarDate(status.expiresAt!)}. التجديد التلقائي ${status.autoRenew ? 'مفعل' : 'موقوف'}.',
      );
    }
    return _tr(
      context,
      '${status.cycle.localizedLabel(context)} plan expired on ${formatCalendarDate(status.expiresAt!)}. Renew the salon plan any time.',
      'انتهت خطة ${status.cycle.localizedLabel(context)} في ${formatCalendarDate(status.expiresAt!)}. يمكنك تجديد الخطة في أي وقت.',
    );
  }

  Future<void> _activateSubscription(SubscriptionCycleOption cycle) async {
    if (_isActivatingSubscription) {
      return;
    }
    if (_hasActiveSubscription(_subscriptionStatus)) {
      _showTopToast(
        context,
        title: _tr(context, 'Subscription locked', 'الاشتراك مقفل'),
        message: _tr(
          context,
          'Your ${_subscriptionStatus!.cycle.localizedLabel(context).toLowerCase()} salon plan is still active. Plan changes stay disabled until ${_subscriptionStatus!.expiresAt == null ? 'the saved expiry date' : formatCalendarDate(_subscriptionStatus!.expiresAt!)}.',
          'خطة الصالون ${_subscriptionStatus!.cycle.localizedLabel(context)} ما زالت مفعلة. لن تتمكن من تغيير الخطة حتى ${_subscriptionStatus!.expiresAt == null ? 'تاريخ الانتهاء المحفوظ' : formatCalendarDate(_subscriptionStatus!.expiresAt!)}.',
        ),
        icon: Icons.workspace_premium_outlined,
      );
      return;
    }

    setState(() => _isActivatingSubscription = true);
    try {
      final SalonSubscriptionStatus updated =
          await widget.platformRepository.activateSalonSubscription(
            user: widget.user,
            cycle: cycle,
          ) ??
          SalonSubscriptionStatus(
            cycle: cycle,
            amount: cycle.salonPrice,
            expiresAt: DateTime.now().add(
              Duration(
                days: cycle == SubscriptionCycleOption.yearly ? 365 : 30,
              ),
            ),
            autoRenew: _subscriptionStatus?.autoRenew ?? false,
          );
      if (!mounted) {
        return;
      }
      setState(() => _subscriptionStatus = updated);
      _showTopToast(
        context,
        title: _tr(
          context,
          'Salon subscription active',
          'تم تفعيل اشتراك الصالون',
        ),
        message: _tr(
          context,
          '${cycle.localizedLabel(context)} plan activated successfully. It expires ${updated.expiresAt == null ? 'on the saved renewal date' : 'on ${formatCalendarDate(updated.expiresAt!)}'}.',
          'تم تفعيل خطة ${cycle.localizedLabel(context)} بنجاح. تنتهي ${updated.expiresAt == null ? 'في تاريخ التجديد المحفوظ' : 'في ${formatCalendarDate(updated.expiresAt!)}'}.',
        ),
        icon: Icons.workspace_premium_rounded,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isActivatingSubscription = false);
      }
    }
  }

  Future<void> _toggleAutoRenew(bool value) async {
    if (_isUpdatingAutoRenew || !_hasActiveSubscription(_subscriptionStatus)) {
      return;
    }

    setState(() => _isUpdatingAutoRenew = true);
    try {
      final SalonSubscriptionStatus updated =
          await widget.platformRepository.updateSalonSubscriptionAutoRenew(
            user: widget.user,
            autoRenew: value,
          ) ??
          _subscriptionStatus!.copyWith(autoRenew: value);
      if (!mounted) {
        return;
      }
      setState(() => _subscriptionStatus = updated);
      _showTopToast(
        context,
        title: value ? 'Auto-renew enabled' : 'Auto-renew disabled',
        message: value
            ? 'Freshline will keep this salon plan ready for renewal when the current cycle ends.'
            : 'Auto-renew is off. You can renew the salon plan manually later.',
        icon: Icons.autorenew_rounded,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingAutoRenew = false);
      }
    }
  }

  Widget _buildSubscriptionPlanCard(
    SubscriptionCycleOption cycle, {
    required bool hasActiveSubscription,
    required bool isCurrentActivePlan,
  }) {
    final bool locked = hasActiveSubscription && !isCurrentActivePlan;
    final bool expiredCurrentPlan =
        !hasActiveSubscription && _subscriptionStatus?.cycle == cycle;
    final VoidCallback? onTap =
        hasActiveSubscription || _isActivatingSubscription
        ? null
        : () => _activateSubscription(cycle);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: locked ? 0.56 : 1,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: appCardDecoration(
            border: Border.all(
              color: isCurrentActivePlan
                  ? AppPalette.primary
                  : AppPalette.border,
              width: isCurrentActivePlan ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      cycle.localizedLabel(context),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    formatBhd(cycle.salonPrice),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                cycle == SubscriptionCycleOption.yearly
                    ? 'Best value for long-term salon billing.'
                    : 'Flexible monthly billing for active salons.',
                style: TextStyle(color: AppPalette.mutedForeground),
              ),
              const SizedBox(height: 14),
              if (isCurrentActivePlan)
                Text(
                  _subscriptionStatus?.expiresAt == null
                      ? 'Expiry date will appear after activation.'
                      : 'Expires ${formatCalendarDate(_subscriptionStatus!.expiresAt!)}.',
                  style: TextStyle(
                    color: AppPalette.primary,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else if (expiredCurrentPlan)
                Text(
                  _subscriptionStatus?.expiresAt == null
                      ? 'This previous plan can be activated again.'
                      : 'Expired ${formatCalendarDate(_subscriptionStatus!.expiresAt!)}.',
                  style: TextStyle(color: AppPalette.mutedForeground),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onTap,
                  child: Text(
                    isCurrentActivePlan
                        ? 'Current Plan'
                        : locked
                        ? 'Locked'
                        : expiredCurrentPlan
                        ? 'Renew Plan'
                        : 'Choose Plan',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasActiveSubscription = _hasActiveSubscription(
      _subscriptionStatus,
    );
    final String currentPlanLabel =
        _subscriptionStatus?.cycle.localizedLabel(context) ??
        _tr(context, 'None', 'لا يوجد');
    final String expiryLabel = _subscriptionStatus?.expiresAt == null
        ? 'Not set'
        : formatCalendarDate(_subscriptionStatus!.expiresAt!);

    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: const Text('Salon Subscription')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.workspace.salon.localizedName(context),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _subscriptionStatusLabel(_subscriptionStatus),
                    style: TextStyle(
                      height: 1.45,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MetricCard(
                    label: 'Current Plan',
                    value: currentPlanLabel,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'Amount',
                    value: formatBhd(_subscriptionStatus?.amount ?? 0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(label: 'Expiry', value: expiryLabel),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Auto-Renew',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasActiveSubscription
                        ? 'Enable or disable auto-renew for the active salon plan.'
                        : 'Auto-renew becomes available after the salon owner activates a plan.',
                    style: TextStyle(
                      height: 1.45,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    value: _subscriptionStatus?.autoRenew ?? false,
                    onChanged: hasActiveSubscription && !_isUpdatingAutoRenew
                        ? _toggleAutoRenew
                        : null,
                    title: Text(
                      _subscriptionStatus?.autoRenew == true
                          ? 'Auto-renew enabled'
                          : 'Auto-renew disabled',
                    ),
                    subtitle: Text(
                      hasActiveSubscription
                          ? 'The current plan will ${_subscriptionStatus?.autoRenew == true ? '' : 'not '}renew automatically at the end of the cycle.'
                          : 'No active plan yet.',
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Choose Plan',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Monthly and yearly salon plans stay here as a separate owner billing screen.',
                    style: TextStyle(
                      height: 1.45,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...SubscriptionCycleOption.values.map((
                    SubscriptionCycleOption cycle,
                  ) {
                    final bool isCurrentActivePlan =
                        hasActiveSubscription &&
                        _subscriptionStatus?.cycle == cycle;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildSubscriptionPlanCard(
                        cycle,
                        hasActiveSubscription: hasActiveSubscription,
                        isCurrentActivePlan: isCurrentActivePlan,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: appCardDecoration(color: AppPalette.background, radius: 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: AppPalette.primary, size: 18),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: AppPalette.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: appCardDecoration(color: AppPalette.background, radius: 22),
      child: Column(
        children: <Widget>[
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _localizedDisplayText(context, label),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: AppPalette.mutedForeground),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TagCard extends StatelessWidget {
  const _TagCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppPalette.secondary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _ManagementAvatar extends StatelessWidget {
  const _ManagementAvatar({
    required this.imagePath,
    required this.radius,
    this.icon = Icons.person_rounded,
  });

  final String imagePath;
  final double radius;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppPalette.secondary,
      foregroundImage: _appImageProvider(imagePath),
      onForegroundImageError: (_, _) {},
      child: Icon(icon, color: AppPalette.primary, size: radius),
    );
  }
}

extension _AppRoleAvatarIcon on AppRole {
  IconData get avatarFallbackIcon {
    switch (this) {
      case AppRole.customer:
        return Icons.person_rounded;
      case AppRole.salonOwner:
        return Icons.storefront_rounded;
      case AppRole.employee:
        return Icons.badge_rounded;
      case AppRole.admin:
        return Icons.admin_panel_settings_rounded;
    }
  }
}

class _ManagementNavigationBar extends StatelessWidget {
  const _ManagementNavigationBar({
    required this.tabs,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<_NavItem> tabs;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppPalette.card.withValues(alpha: 0.97),
        border: Border(top: BorderSide(color: AppPalette.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        8,
        8,
        8,
        MediaQuery.viewPaddingOf(context).bottom + 8,
      ),
      child: Row(
        children: List<Widget>.generate(tabs.length, (int index) {
          final bool active = currentIndex == index;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => onSelect(index),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      tabs[index].icon,
                      size: 22,
                      color: active
                          ? AppPalette.primary
                          : AppPalette.mutedForeground,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tabs[index].label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: active
                            ? AppPalette.primary
                            : AppPalette.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class SalonOwnerOnboardingScreen extends StatefulWidget {
  const SalonOwnerOnboardingScreen({super.key, required this.repository});

  final SalonOwnerRepository repository;

  @override
  State<SalonOwnerOnboardingScreen> createState() =>
      _SalonOwnerOnboardingScreenState();
}

class _SalonOwnerOnboardingScreenState
    extends State<SalonOwnerOnboardingScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _hidePassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _ownerNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final SalonOwnerSession session = await widget.repository.registerOwner(
        ownerName: _ownerNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(session);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: const Text('Register Your Salon')),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _AuthBrandHeader(
                    subtitle:
                        'Create the salon owner account first with the basic details below.',
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: appCardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Owner Account',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Only the owner name, email, and password are needed in this first step.',
                          style: TextStyle(
                            color: AppPalette.mutedForeground,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _AuthTextField(
                          controller: _ownerNameController,
                          label: 'Salon Owner Name',
                          validator: _required,
                        ),
                        const SizedBox(height: 14),
                        _AuthTextField(
                          controller: _emailController,
                          label: 'Owner Email',
                          keyboardType: TextInputType.emailAddress,
                          validator: _requiredEmail,
                        ),
                        const SizedBox(height: 14),
                        _AuthTextField(
                          controller: _passwordController,
                          label: 'Password',
                          obscureText: _hidePassword,
                          validator: _passwordValidator,
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _hidePassword = !_hidePassword);
                            },
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: Text(
                        _isSubmitting
                            ? 'Creating Owner Account...'
                            : 'Create Owner Account',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'This field is required.';
    }
    return null;
  }

  String? _requiredEmail(String? value) {
    if ((value ?? '').trim().isEmpty || !(value ?? '').contains('@')) {
      return 'Enter a valid email.';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    if ((value ?? '').trim().length < 6) {
      return 'Use at least 6 characters.';
    }
    return null;
  }
}

class SalonOwnerShell extends StatefulWidget {
  const SalonOwnerShell({
    super.key,
    required this.user,
    required this.onLogout,
    required this.repository,
    required this.platformRepository,
    required this.notificationsService,
    required this.initialRequest,
    required this.onRequestChanged,
    required this.onUserChanged,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.isHighContrast,
    required this.onHighContrastChanged,
    required this.textScaleFactor,
    required this.onTextScaleChanged,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    required this.isBiometricLockEnabled,
    required this.onBiometricLockChanged,
  });

  final AppUser user;
  final VoidCallback onLogout;
  final SalonOwnerRepository repository;
  final PlatformRepository platformRepository;
  final NotificationsService notificationsService;
  final SalonRegistrationRequest? initialRequest;
  final ValueChanged<SalonRegistrationRequest?> onRequestChanged;
  final ValueChanged<AppUser> onUserChanged;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final bool isHighContrast;
  final ValueChanged<bool> onHighContrastChanged;
  final double textScaleFactor;
  final ValueChanged<double> onTextScaleChanged;
  final String selectedLanguage;
  final ValueChanged<String> onLanguageChanged;
  final bool isBiometricLockEnabled;
  final AsyncBoolCallback onBiometricLockChanged;

  @override
  State<SalonOwnerShell> createState() => _SalonOwnerShellState();
}

class _SalonOwnerShellState extends State<SalonOwnerShell> {
  int _currentIndex = 0;
  late AppUser _user = widget.user;
  SalonRegistrationRequest? _request;
  bool _isLoadingRequest = false;
  SalonWorkspaceSnapshot? _workspace;
  bool _isLoadingWorkspace = false;
  List<AppNotificationItem> _notifications = <AppNotificationItem>[];
  bool _isNotificationsLoading = false;

  @override
  void initState() {
    super.initState();
    _request = widget.initialRequest;
    _refreshRequest(showLoading: _request == null);
    _loadNotifications(showLoading: false);
  }

  @override
  void didUpdateWidget(covariant SalonOwnerShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedLanguage != oldWidget.selectedLanguage ||
        widget.user.preferredLanguage != oldWidget.user.preferredLanguage ||
        widget.user.profileId != oldWidget.user.profileId) {
      unawaited(_refreshRequest(showLoading: false));
      unawaited(_loadNotifications(showLoading: false));
    }
  }

  Future<void> _refreshRequest({bool showLoading = true}) async {
    if (widget.user.profileId == null) {
      return;
    }

    if (showLoading && mounted) {
      setState(() => _isLoadingRequest = true);
    }

    try {
      final SalonRegistrationRequest? latest = await widget.repository
          .loadLatestRequest(owner: _user);
      if (!mounted) {
        return;
      }
      setState(() => _request = latest);
      widget.onRequestChanged(latest);
      if (latest?.isApproved ?? false) {
        unawaited(_refreshWorkspace(showLoading: _workspace == null));
      } else {
        setState(() => _workspace = null);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingRequest = false);
      }
    }
  }

  Future<void> _refreshWorkspace({bool showLoading = true}) async {
    if (!_isApproved) {
      return;
    }

    if (showLoading && mounted) {
      setState(() => _isLoadingWorkspace = true);
    }

    try {
      final SalonWorkspaceSnapshot workspace = await widget.platformRepository
          .loadSalonWorkspace(user: _user);
      if (!mounted) {
        return;
      }
      setState(() => _workspace = workspace);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingWorkspace = false);
      }
    }
  }

  Future<void> _loadNotifications({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => _isNotificationsLoading = true);
    }

    try {
      final List<AppNotificationItem> notifications = await widget
          .notificationsService
          .loadNotifications(user: _user);
      if (!mounted) {
        return;
      }
      setState(() => _notifications = notifications);
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() => _isNotificationsLoading = false);
      }
    }
  }

  Future<void> _openNotifications() async {
    await _loadNotifications();
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => NotificationsScreen(
          notifications: _notifications,
          isLoading: _isNotificationsLoading,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _notifications = _notifications
          .map(
            (AppNotificationItem item) =>
                item.unread ? item.copyWith(unread: false) : item,
          )
          .toList(growable: false);
    });
  }

  bool get _hasUnreadNotifications =>
      _notifications.any((AppNotificationItem item) => item.unread);

  Future<void> _openProfitDetails() async {
    final SalonWorkspaceSnapshot? workspace = _workspace;
    if (workspace == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SalonFinanceDetailsScreen(
          user: _user,
          workspace: workspace,
          platformRepository: widget.platformRepository,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    await _refreshWorkspace(showLoading: false);
  }

  Future<void> _openSubscriptionDetails() async {
    final SalonWorkspaceSnapshot? workspace = _workspace;
    if (workspace == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SalonOwnerSubscriptionScreen(
          user: _user,
          workspace: workspace,
          platformRepository: widget.platformRepository,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    await _refreshWorkspace(showLoading: false);
  }

  Future<void> _openCatalogDetails() async {
    final SalonWorkspaceSnapshot? workspace = _workspace;
    if (workspace == null) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SalonOwnerCatalogScreen(
          actor: _user,
          platformRepository: widget.platformRepository,
          workspace: workspace,
          isLoading: _isLoadingWorkspace,
          onRefresh: _refreshWorkspace,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    await _refreshWorkspace(showLoading: false);
  }

  Future<void> _openRequestEditor() async {
    final SalonRegistrationRequest? saved = await Navigator.of(context)
        .push<SalonRegistrationRequest>(
          MaterialPageRoute<SalonRegistrationRequest>(
            builder: (BuildContext context) => SalonOwnerRequestEditorScreen(
              owner: _user,
              repository: widget.repository,
              existingRequest: _request,
            ),
          ),
        );

    if (saved == null || !mounted) {
      return;
    }

    setState(() => _request = saved);
    widget.onRequestChanged(saved);
    if (saved.isApproved) {
      await _refreshWorkspace();
    }
  }

  bool get _isApproved => _request?.isApproved ?? false;

  String get _lockedTitle {
    if (_request == null) {
      return 'Create your salon request first';
    }
    return _request!.status == SalonRequestStatus.rejected
        ? 'The request was rejected'
        : _request!.status == SalonRequestStatus.needsInfo
        ? 'Update the request details'
        : 'Waiting for admin approval';
  }

  String get _lockedMessage {
    if (_request == null) {
      return 'Tap Add a New Request, upload the salon image and PDFs, then submit the salon profile for review.';
    }
    if (_request!.status == SalonRequestStatus.rejected) {
      return 'Your team, bookings, and earnings open after a fresh approved request.';
    }
    if (_request!.status == SalonRequestStatus.needsInfo) {
      return 'The admin asked for more details. Edit the request, upload the corrected files, and submit again.';
    }
    return 'Your salon request is pending. Team management, bookings, and earnings unlock once admin approves the salon.';
  }

  @override
  Widget build(BuildContext context) {
    final List<_NavItem> tabs = <_NavItem>[
      _NavItem(
        Icons.dashboard_customize_rounded,
        _tr(context, 'Dashboard', 'لوحة التحكم'),
      ),
      _NavItem(
        Icons.calendar_month_rounded,
        _tr(context, 'Bookings', 'الحجوزات'),
      ),
      _NavItem(Icons.group_outlined, _tr(context, 'Team', 'الفريق')),
      _NavItem(Icons.auto_awesome_rounded, _tr(context, 'AI', 'الذكاء')),
      _NavItem(Icons.settings_rounded, _tr(context, 'Settings', 'الإعدادات')),
    ];

    final Widget dashboardPage = _isApproved
        ? SalonOwnerDashboardScreen(
            user: _user,
            workspace: _workspace,
            isLoading: _isLoadingWorkspace,
            onRefresh: _refreshWorkspace,
            onOpenNotifications: _openNotifications,
            hasUnreadNotifications: _hasUnreadNotifications,
            onOpenProfitDetails: _openProfitDetails,
            onOpenSubscriptionDetails: _openSubscriptionDetails,
            onOpenBookingsTab: () {
              setState(() => _currentIndex = 1);
            },
            onOpenTeamTab: () {
              setState(() => _currentIndex = 2);
            },
            onOpenCatalogDetails: () => unawaited(_openCatalogDetails()),
          )
        : SalonOwnerRequestHubScreen(
            owner: _user,
            request: _request,
            isLoading: _isLoadingRequest,
            onAddRequest: _openRequestEditor,
            onEditRequest: _openRequestEditor,
            onRefresh: _refreshRequest,
          );

    final Widget lockedScreen = SalonOwnerLockedFeatureScreen(
      title: _lockedTitle,
      message: _lockedMessage,
      actionLabel: _request == null ? 'Add a New Request' : 'Review Request',
      onAction: () {
        setState(() => _currentIndex = 0);
      },
    );

    final List<Widget> pages = <Widget>[
      dashboardPage,
      _isApproved
          ? SalonOwnerBookingsScreen(
              actor: _user,
              platformRepository: widget.platformRepository,
              workspace: _workspace,
              isLoading: _isLoadingWorkspace,
              onRefresh: _refreshWorkspace,
            )
          : lockedScreen,
      _isApproved
          ? SalonOwnerTeamScreen(
              actor: _user,
              platformRepository: widget.platformRepository,
              workspace: _workspace,
              isLoading: _isLoadingWorkspace,
              onRefresh: _refreshWorkspace,
            )
          : lockedScreen,
      AiStylistScreen(
        role: AppRole.salonOwner,
        selectedLanguage: widget.selectedLanguage,
      ),
      SalonOwnerSettingsScreen(
        user: _user,
        workspace: _workspace,
        platformRepository: widget.platformRepository,
        onOpenNotifications: _openNotifications,
        onUserChanged: (AppUser updatedUser) {
          setState(() => _user = updatedUser);
          widget.onUserChanged(updatedUser);
          unawaited(_refreshWorkspace(showLoading: false));
          unawaited(_loadNotifications(showLoading: false));
        },
        onOpenCatalogDetails: _openCatalogDetails,
        onOpenSubscriptionDetails: _openSubscriptionDetails,
        onOpenProfitDetails: _openProfitDetails,
        onLogout: widget.onLogout,
        isDarkMode: widget.isDarkMode,
        onThemeChanged: widget.onThemeChanged,
        isHighContrast: widget.isHighContrast,
        onHighContrastChanged: widget.onHighContrastChanged,
        textScaleFactor: widget.textScaleFactor,
        onTextScaleChanged: widget.onTextScaleChanged,
        selectedLanguage: widget.selectedLanguage,
        onLanguageChanged: widget.onLanguageChanged,
        isBiometricLockEnabled: widget.isBiometricLockEnabled,
        onBiometricLockChanged: widget.onBiometricLockChanged,
      ),
    ];

    return AppViewport(
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: pages),
        bottomNavigationBar: _ManagementNavigationBar(
          tabs: tabs,
          currentIndex: _currentIndex,
          onSelect: (int index) => setState(() => _currentIndex = index),
        ),
      ),
    );
  }
}

class SalonOwnerRequestHubScreen extends StatelessWidget {
  const SalonOwnerRequestHubScreen({
    super.key,
    required this.owner,
    required this.request,
    required this.isLoading,
    required this.onAddRequest,
    required this.onEditRequest,
    required this.onRefresh,
  });

  final AppUser owner;
  final SalonRegistrationRequest? request;
  final bool isLoading;
  final Future<void> Function() onAddRequest;
  final Future<void> Function() onEditRequest;
  final Future<void> Function({bool showLoading}) onRefresh;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: <Widget>[
          Text(
            owner.name,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            request == null
                ? 'Your first step is to create a salon request.'
                : 'Your salon request stays here until admin reviews it.',
            style: TextStyle(color: AppPalette.mutedForeground),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: appCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppPalette.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        request == null
                            ? _tr(context, 'New', 'جديد')
                            : request!.status.localizedLabel(context),
                        style: TextStyle(
                          color: AppPalette.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: isLoading ? null : () => onRefresh(),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  request == null ? 'Add a New Request' : request!.salonName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  request == null
                      ? 'Upload the salon image, commercial registration, government license, salon email, salon phone number, and location URL. Once submitted, the request becomes pending and stays editable before approval.'
                      : 'Salon email: ${request!.salonEmail}\nSalon phone: ${request!.salonPhone}\nCity: ${request!.city}\nAddress: ${request!.address}\nLocation URL: ${request!.locationUrl}${request!.websiteUrl == null || request!.websiteUrl!.trim().isEmpty ? '' : '\nWebsite: ${request!.websiteUrl}'}',
                  style: TextStyle(
                    height: 1.55,
                    color: AppPalette.mutedForeground,
                  ),
                ),
                if (request?.adminNote != null &&
                    request!.adminNote!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: appCardDecoration(
                      color: AppPalette.secondary,
                      radius: 18,
                    ),
                    child: Text(
                      request!.adminNote!,
                      style: TextStyle(color: AppPalette.mutedForeground),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                if (isLoading)
                  const LinearProgressIndicator(minHeight: 3)
                else if (request == null)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => onAddRequest(),
                      child: const Text('Add a New Request'),
                    ),
                  )
                else
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: request!.isEditable
                              ? () => onEditRequest()
                              : null,
                          child: Text(
                            request!.isEditable
                                ? 'Edit Request'
                                : 'Locked After Review',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => onRefresh(showLoading: true),
                          child: const Text('Refresh Status'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: appCardDecoration(color: AppPalette.secondary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'What happens next?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  '1. Admin reviews the request.\n2. The request stays pending until approval.\n3. You can edit it while it is pending or needs info.\n4. After approval, the salon dashboard, team, services, and bookings become available.',
                  style: TextStyle(
                    height: 1.55,
                    color: AppPalette.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          if (request != null) ...<Widget>[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Uploaded Files',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  _UploadSummaryRow(
                    label: 'Salon Image',
                    value: request!.salonImage?.fileName ?? 'Missing',
                  ),
                  if (request!.salonImage != null) ...<Widget>[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: _AppImage(
                        imagePath: request!.salonImage!.publicUrl,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _UploadSummaryRow(
                    label: 'Commercial Registration',
                    value:
                        request!.commercialRegistration?.fileName ?? 'Missing',
                  ),
                  if (request!.commercialRegistration != null) ...<Widget>[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _launchUri(
                          context,
                          Uri.parse(request!.commercialRegistration!.publicUrl),
                          'Could not open the commercial registration file.',
                          fallbackClipboardValue:
                              request!.commercialRegistration!.publicUrl,
                          fallbackConfirmation:
                              'Commercial registration link copied.',
                        ),
                        child: const Text('Open Commercial Registration'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _UploadSummaryRow(
                    label: 'Government License',
                    value: request!.governmentLicense?.fileName ?? 'Missing',
                  ),
                  if (request!.governmentLicense != null) ...<Widget>[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _launchUri(
                          context,
                          Uri.parse(request!.governmentLicense!.publicUrl),
                          'Could not open the government license file.',
                          fallbackClipboardValue:
                              request!.governmentLicense!.publicUrl,
                          fallbackConfirmation:
                              'Government license link copied.',
                        ),
                        child: const Text('Open Government License'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UploadSummaryRow extends StatelessWidget {
  const _UploadSummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: AppPalette.mutedForeground),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class SalonOwnerRequestEditorScreen extends StatefulWidget {
  const SalonOwnerRequestEditorScreen({
    super.key,
    required this.owner,
    required this.repository,
    this.existingRequest,
  });

  final AppUser owner;
  final SalonOwnerRepository repository;
  final SalonRegistrationRequest? existingRequest;

  @override
  State<SalonOwnerRequestEditorScreen> createState() =>
      _SalonOwnerRequestEditorScreenState();
}

class _SalonOwnerRequestEditorScreenState
    extends State<SalonOwnerRequestEditorScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _salonNameController = TextEditingController(
    text: widget.existingRequest?.salonName ?? '',
  );
  late final TextEditingController _salonEmailController =
      TextEditingController(text: widget.existingRequest?.salonEmail ?? '');
  late final TextEditingController _salonPhoneController =
      TextEditingController(
        text:
            normalizeBahrainPhone(
              widget.existingRequest?.salonPhone,
              allowEmpty: true,
            ) ??
            (widget.existingRequest?.salonPhone ?? '').trim(),
      );
  late final TextEditingController _cityController = TextEditingController(
    text: normalizeBahrainLocation(
      widget.existingRequest?.city ?? widget.owner.city,
    ),
  );
  late final TextEditingController _addressController = TextEditingController(
    text: widget.existingRequest?.address ?? '',
  );
  late final TextEditingController _locationUrlController =
      TextEditingController(text: widget.existingRequest?.locationUrl ?? '');
  late final TextEditingController _websiteController = TextEditingController(
    text: widget.existingRequest?.websiteUrl ?? '',
  );

  UploadedSalonAsset? _salonImage;
  UploadedSalonAsset? _commercialRegistration;
  UploadedSalonAsset? _governmentLicense;
  bool _isSaving = false;
  SalonUploadType? _uploadingType;

  @override
  void initState() {
    super.initState();
    _salonImage = widget.existingRequest?.salonImage;
    _commercialRegistration = widget.existingRequest?.commercialRegistration;
    _governmentLicense = widget.existingRequest?.governmentLicense;
  }

  @override
  void dispose() {
    _salonNameController.dispose();
    _salonEmailController.dispose();
    _salonPhoneController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _locationUrlController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _upload(SalonUploadType type) async {
    setState(() => _uploadingType = type);
    try {
      final UploadedSalonAsset? asset = await widget.repository
          .pickAndUploadAsset(owner: widget.owner, type: type);
      if (asset == null || !mounted) {
        return;
      }

      setState(() {
        switch (type) {
          case SalonUploadType.salonImage:
            _salonImage = asset;
          case SalonUploadType.commercialRegistration:
            _commercialRegistration = asset;
          case SalonUploadType.governmentLicense:
            _governmentLicense = asset;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingType = null);
      }
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_salonImage == null ||
        _commercialRegistration == null ||
        _governmentLicense == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Upload the salon image and the two required PDFs first.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final SalonRegistrationRequest request = SalonRegistrationRequest(
        id: widget.existingRequest?.id,
        ownerId: widget.owner.profileId ?? '',
        salonName: _salonNameController.text.trim(),
        salonEmail: _salonEmailController.text.trim(),
        salonPhone: normalizeBahrainPhoneOrThrow(
          _salonPhoneController.text,
          fieldLabel: 'Salon phone number',
        ),
        city: normalizeBahrainLocation(_cityController.text),
        address: _addressController.text.trim(),
        locationUrl: _locationUrlController.text.trim(),
        websiteUrl: _websiteController.text.trim().isEmpty
            ? null
            : _websiteController.text.trim(),
        salonImage: _salonImage,
        commercialRegistration: _commercialRegistration,
        governmentLicense: _governmentLicense,
        status: widget.existingRequest?.status ?? SalonRequestStatus.pending,
        createdAt: widget.existingRequest?.createdAt,
      );
      final SalonRegistrationRequest saved = await widget.repository
          .saveRequest(owner: widget.owner, request: request);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(saved);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.existingRequest != null;
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Edit Request' : 'Add a New Request'),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _AuthBrandHeader(
                    subtitle:
                        '${widget.owner.name}, upload the salon image and the required files. This request is stored in Supabase and stays pending until admin review.',
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: appCardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Salon Request',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _AuthTextField(
                          controller: _salonNameController,
                          label: 'Salon Name',
                          validator: _required,
                        ),
                        const SizedBox(height: 14),
                        _AuthTextField(
                          controller: _salonEmailController,
                          label: 'Salon Email',
                          keyboardType: TextInputType.emailAddress,
                          validator: _requiredEmail,
                        ),
                        const SizedBox(height: 14),
                        _AuthTextField(
                          controller: _salonPhoneController,
                          label: 'Salon Phone Number',
                          keyboardType: TextInputType.phone,
                          validator: validateRequiredBahrainPhone,
                          inputFormatters: bahrainPhoneInputFormatters,
                        ),
                        const SizedBox(height: 14),
                        _BahrainLocationDropdownField(
                          controller: _cityController,
                          label: 'City',
                          validator: _required,
                        ),
                        const SizedBox(height: 14),
                        _AuthTextField(
                          controller: _addressController,
                          label: 'Full Address',
                          maxLines: 3,
                          validator: _required,
                        ),
                        const SizedBox(height: 14),
                        _AuthTextField(
                          controller: _locationUrlController,
                          label: 'Location URL',
                          keyboardType: TextInputType.url,
                          validator: _required,
                        ),
                        const SizedBox(height: 14),
                        _AuthTextField(
                          controller: _websiteController,
                          label: 'Website URL (Optional)',
                          keyboardType: TextInputType.url,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _UploadTile(
                    title: 'Salon Image',
                    subtitle:
                        'Upload the main salon photo to Supabase Storage.',
                    asset: _salonImage,
                    isUploading: _uploadingType == SalonUploadType.salonImage,
                    onTap: () => _upload(SalonUploadType.salonImage),
                  ),
                  const SizedBox(height: 12),
                  _UploadTile(
                    title: 'Commercial Registration PDF',
                    subtitle: 'Upload the commercial registration file.',
                    asset: _commercialRegistration,
                    isUploading:
                        _uploadingType ==
                        SalonUploadType.commercialRegistration,
                    onTap: () =>
                        _upload(SalonUploadType.commercialRegistration),
                  ),
                  const SizedBox(height: 12),
                  _UploadTile(
                    title: 'Government License PDF',
                    subtitle: 'Upload the government salon registration file.',
                    asset: _governmentLicense,
                    isUploading:
                        _uploadingType == SalonUploadType.governmentLicense,
                    onTap: () => _upload(SalonUploadType.governmentLicense),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _submit,
                      child: Text(
                        _isSaving
                            ? 'Saving Request...'
                            : isEditing
                            ? 'Update Request'
                            : 'Submit Request',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'This field is required.';
    }
    return null;
  }

  String? _requiredEmail(String? value) {
    if ((value ?? '').trim().isEmpty || !(value ?? '').contains('@')) {
      return 'Enter a valid email.';
    }
    return null;
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.title,
    required this.subtitle,
    required this.asset,
    required this.isUploading,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final UploadedSalonAsset? asset;
  final bool isUploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                asset == null
                    ? Icons.upload_file_outlined
                    : Icons.check_circle_rounded,
                color: asset == null ? AppPalette.primary : Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: AppPalette.mutedForeground, height: 1.45),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: appCardDecoration(
              color: AppPalette.background,
              radius: 18,
            ),
            child: Text(
              asset?.fileName ?? 'No file uploaded yet',
              style: TextStyle(
                color: asset == null
                    ? AppPalette.mutedForeground
                    : AppPalette.foreground,
                fontWeight: asset == null ? FontWeight.w500 : FontWeight.w700,
              ),
            ),
          ),
          if (asset != null &&
              asset!.contentType.startsWith('image/')) ...<Widget>[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: _AppImage(
                imagePath: asset!.publicUrl,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isUploading ? null : onTap,
                  icon: isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file_rounded),
                  label: Text(asset == null ? 'Upload File' : 'Replace File'),
                ),
              ),
              if (asset != null) ...<Widget>[
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _launchUri(
                      context,
                      Uri.parse(asset!.publicUrl),
                      'Could not open the uploaded file.',
                      fallbackClipboardValue: asset!.publicUrl,
                      fallbackConfirmation: 'Uploaded file link copied.',
                    ),
                    child: const Text('View File'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: AppPalette.mutedForeground, height: 1.45),
        ),
      ],
    );
  }
}

class _ManagementNotificationsButton extends StatelessWidget {
  const _ManagementNotificationsButton({
    required this.hasUnread,
    required this.onTap,
  });

  final bool hasUnread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppPalette.secondary,
          shape: BoxShape.circle,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            const Center(
              child: Icon(Icons.notifications_none_rounded, size: 22),
            ),
            if (hasUnread)
              Positioned(
                top: 8,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppPalette.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SalonOwnerLockedFeatureScreen extends StatelessWidget {
  const SalonOwnerLockedFeatureScreen({
    super.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        child: _EmptyStateCard(
          icon: Icons.pending_actions_rounded,
          title: title,
          message: message,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      ),
    );
  }
}

class SalonOwnerDashboardScreen extends StatelessWidget {
  const SalonOwnerDashboardScreen({
    super.key,
    required this.user,
    required this.workspace,
    required this.isLoading,
    required this.onRefresh,
    required this.onOpenNotifications,
    required this.hasUnreadNotifications,
    required this.onOpenProfitDetails,
    required this.onOpenSubscriptionDetails,
    required this.onOpenBookingsTab,
    required this.onOpenTeamTab,
    required this.onOpenCatalogDetails,
  });

  final AppUser user;
  final SalonWorkspaceSnapshot? workspace;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onOpenNotifications;
  final bool hasUnreadNotifications;
  final Future<void> Function() onOpenProfitDetails;
  final Future<void> Function() onOpenSubscriptionDetails;
  final VoidCallback onOpenBookingsTab;
  final VoidCallback onOpenTeamTab;
  final VoidCallback onOpenCatalogDetails;

  @override
  Widget build(BuildContext context) {
    final SalonWorkspaceSnapshot? workspace = this.workspace;
    if (isLoading && workspace == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (workspace == null) {
      return SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          child: _EmptyStateCard(
            icon: Icons.storefront_outlined,
            title: 'Salon workspace is not ready',
            message:
                'Refresh the approved salon workspace to load earnings, bookings, and team details.',
            actionLabel: 'Refresh',
            onAction: () => unawaited(onRefresh()),
          ),
        ),
      );
    }

    final SalonFinanceSnapshot finance = workspace.finance;
    final double operatingProfit =
        finance.totalRevenue - finance.salaryCost - finance.subscriptionCost;
    final int activeEmployees = workspace.employees
        .where((Employee employee) => employee.isActive)
        .length;
    final int pausedEmployees = workspace.employees.length - activeEmployees;
    final int activePackages = workspace.packages
        .where((ServicePackage item) => item.isActive)
        .length;
    final int activeServices = workspace.services
        .where((ServiceItem item) => item.isActive)
        .length;
    final int activeProducts = workspace.products
        .where((Product item) => item.isActive)
        .length;
    final int activeOffers = workspace.coupons
        .where(
          (PromoCouponRecord coupon) =>
              coupon.isActive && coupon.isAvailableAt(DateTime.now()),
        )
        .length;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: appCardDecoration(),
            child: Row(
              children: <Widget>[
                _ManagementAvatar(
                  imagePath: user.avatarPath,
                  radius: 32,
                  icon: Icons.storefront_rounded,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        workspace.salon.localizedName(context),
                        style: TextStyle(
                          color: AppPalette.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${workspace.salon.localizedLocation(context)} · ${workspace.salon.rating.toStringAsFixed(1)} (${workspace.salon.reviews})',
                        style: TextStyle(color: AppPalette.mutedForeground),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _ManagementNotificationsButton(
                  hasUnread: hasUnreadNotifications,
                  onTap: () => unawaited(onOpenNotifications()),
                ),
                IconButton(
                  onPressed: () => unawaited(onRefresh()),
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: appCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Salon is approved and visible in Freshline',
                    style: TextStyle(
                      color: AppPalette.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Track revenue, team cost, subscription cost, and overall performance from one owner dashboard.',
                  style: TextStyle(
                    height: 1.5,
                    color: AppPalette.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.insights_outlined,
                  label: 'Profit',
                  value: formatBhd(operatingProfit),
                  onTap: () => unawaited(onOpenProfitDetails()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.workspace_premium_outlined,
                  label: 'Subscription',
                  value:
                      workspace.subscriptionStatus?.cycle.localizedLabel(
                        context,
                      ) ??
                      _tr(context, 'Inactive', 'غير نشط'),
                  onTap: () => unawaited(onOpenSubscriptionDetails()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.calendar_today_outlined,
                  label: 'Bookings',
                  value:
                      '${finance.upcomingBookings + finance.completedBookings}',
                  onTap: onOpenBookingsTab,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.group_outlined,
                  label: 'Team',
                  value: '$activeEmployees/${workspace.employees.length}',
                  onTap: onOpenTeamTab,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.spa_outlined,
                  label: 'Catalog',
                  value:
                      '${workspace.packages.length + workspace.services.length + workspace.products.length}',
                  onTap: onOpenCatalogDetails,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: appCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Live Finance Snapshot',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _MetricCard(
                        label: 'Operating Profit',
                        value: formatBhd(operatingProfit),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        label: 'Salary Cost',
                        value: formatBhd(finance.salaryCost),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        label: 'Subscription',
                        value: formatBhd(finance.subscriptionCost),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => unawaited(onOpenProfitDetails()),
                    child: const Text('Open Revenue & Profit'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: appCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Management shortcuts',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    _TagCard(
                      label:
                          '${finance.upcomingBookings} upcoming booking${finance.upcomingBookings == 1 ? '' : 's'}',
                    ),
                    _TagCard(
                      label:
                          '${finance.completedBookings} completed booking${finance.completedBookings == 1 ? '' : 's'}',
                    ),
                    _TagCard(
                      label:
                          '$activeEmployees active employee${activeEmployees == 1 ? '' : 's'}',
                    ),
                    _TagCard(
                      label:
                          '$activePackages package${activePackages == 1 ? '' : 's'} live',
                    ),
                    _TagCard(
                      label:
                          '$activeServices service${activeServices == 1 ? '' : 's'} live',
                    ),
                    _TagCard(
                      label:
                          '$activeProducts product${activeProducts == 1 ? '' : 's'} live',
                    ),
                    _TagCard(
                      label:
                          '$activeOffers active offer${activeOffers == 1 ? '' : 's'}',
                    ),
                    if (pausedEmployees > 0)
                      _TagCard(
                        label:
                            '$pausedEmployees paused account${pausedEmployees == 1 ? '' : 's'}',
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Booking revenue: ${formatBhd(finance.bookingRevenue)}. Open Catalog to manage ${workspace.packages.length} packages, ${workspace.services.length} services, and ${workspace.products.length} products, then open Subscription to manage your current salon plan.',
                  style: TextStyle(color: AppPalette.mutedForeground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SalonOwnerBookingsScreen extends StatefulWidget {
  const SalonOwnerBookingsScreen({
    super.key,
    required this.actor,
    required this.platformRepository,
    required this.workspace,
    required this.isLoading,
    required this.onRefresh,
  });

  final AppUser actor;
  final PlatformRepository platformRepository;
  final SalonWorkspaceSnapshot? workspace;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  @override
  State<SalonOwnerBookingsScreen> createState() =>
      _SalonOwnerBookingsScreenState();
}

class _SalonOwnerBookingsScreenState extends State<SalonOwnerBookingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  _ManagementOrderSearchField _searchField = _ManagementOrderSearchField.phone;
  _ManagementWorkspaceViewFilter _viewFilter =
      _ManagementWorkspaceViewFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesOrder(UserOrder order) {
    final String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }

    switch (_searchField) {
      case _ManagementOrderSearchField.phone:
        return (order.customerPhone ?? '').trim().toLowerCase().contains(query);
      case _ManagementOrderSearchField.invoice:
        return order.displayInvoiceNumber.toLowerCase().contains(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SalonWorkspaceSnapshot? workspace = widget.workspace;
    if (widget.isLoading && workspace == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (workspace == null) {
      return SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          child: _EmptyStateCard(
            icon: Icons.calendar_month_outlined,
            title: 'No salon bookings loaded',
            message:
                'Refresh the workspace to load customer bookings for your salon.',
            actionLabel: 'Refresh',
            onAction: () => unawaited(widget.onRefresh()),
          ),
        ),
      );
    }

    final List<UserOrder> bookings = workspace.bookings;
    final List<UserOrder> productOrders = workspace.productOrders;
    final SalonFinanceSnapshot finance = workspace.finance;
    final List<UserOrder> filteredProductOrders = productOrders
        .where(_matchesOrder)
        .toList(growable: false);
    final List<UserOrder> filteredBookings = bookings
        .where(_matchesOrder)
        .toList(growable: false);
    final bool showProductOrders =
        _viewFilter != _ManagementWorkspaceViewFilter.appointments;
    final bool showAppointments =
        _viewFilter != _ManagementWorkspaceViewFilter.productOrders;
    final bool hasSearchQuery = _searchController.text.trim().isNotEmpty;
    final bool hasVisibleResults =
        (!showProductOrders || filteredProductOrders.isNotEmpty) ||
        (!showAppointments || filteredBookings.isNotEmpty);

    Future<void> openProductOrder(UserOrder order) async {
      final bool? changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (BuildContext context) =>
              ManagementProductOrderDetailsScreen(
                actor: widget.actor,
                platformRepository: widget.platformRepository,
                order: order,
              ),
        ),
      );
      if (changed == true) {
        await widget.onRefresh();
      }
    }

    Future<void> openBooking(UserOrder order) async {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              ManagementSalonBookingDetailsScreen(order: order),
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Orders & Bookings',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => unawaited(widget.onRefresh()),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: appCardDecoration(),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _MetricCard(
                    label: 'Product orders',
                    value: '${productOrders.length}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'Bookings',
                    value: '${bookings.length}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'Revenue',
                    value: formatBhd(finance.totalRevenue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: appCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: _searchField == _ManagementOrderSearchField.phone
                        ? 'Search by phone number'
                        : 'Search by invoice number',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.trim().isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _ManagementOrderSearchField.values
                      .map((_ManagementOrderSearchField field) {
                        return ChoiceChip(
                          label: Text(field.label),
                          selected: _searchField == field,
                          selectedColor: AppPalette.primary.withValues(
                            alpha: 0.16,
                          ),
                          side: BorderSide(
                            color: _searchField == field
                                ? AppPalette.primary
                                : AppPalette.border,
                          ),
                          onSelected: (_) {
                            setState(() => _searchField = field);
                          },
                        );
                      })
                      .toList(growable: false),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _ManagementWorkspaceViewFilter.values
                      .map((_ManagementWorkspaceViewFilter filter) {
                        return ChoiceChip(
                          label: Text(filter.label),
                          selected: _viewFilter == filter,
                          selectedColor: AppPalette.primary.withValues(
                            alpha: 0.16,
                          ),
                          side: BorderSide(
                            color: _viewFilter == filter
                                ? AppPalette.primary
                                : AppPalette.border,
                          ),
                          onSelected: (_) {
                            setState(() => _viewFilter = filter);
                          },
                        );
                      })
                      .toList(growable: false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (hasSearchQuery && !hasVisibleResults)
            _EmptyStateCard(
              icon: Icons.search_off_rounded,
              title: 'No matching results',
              message:
                  'Try a different phone number or invoice number, or switch the visible type.',
            )
          else ...<Widget>[
            if (showProductOrders) ...<Widget>[
              Text(
                'Product Orders',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.foreground,
                ),
              ),
              const SizedBox(height: 12),
              if (filteredProductOrders.isEmpty)
                _EmptyStateCard(
                  icon: Icons.inventory_2_outlined,
                  title: 'No product orders found',
                  message: hasSearchQuery
                      ? 'No product orders match the current search.'
                      : 'Salon product orders will appear here once customers start buying from your catalog.',
                )
              else
                ...filteredProductOrders.map((UserOrder order) {
                  final bool completed = _isManagementOrderCompleted(order);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => unawaited(openProductOrder(order)),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: appCardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    order.serviceName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: completed
                                        ? AppPalette.secondary
                                        : AppPalette.primary.withValues(
                                            alpha: 0.12,
                                          ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    order.statusLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: completed
                                          ? AppPalette.foreground
                                          : AppPalette.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _AccountInfoRow(
                              label: 'Invoice',
                              value: order.displayInvoiceNumber,
                            ),
                            const SizedBox(height: 8),
                            _AccountInfoRow(
                              label: 'Customer',
                              value: order.customerName ?? 'Freshline Customer',
                            ),
                            if ((order.customerPhone ?? '')
                                .trim()
                                .isNotEmpty) ...<Widget>[
                              const SizedBox(height: 8),
                              _AccountInfoRow(
                                label: 'Phone',
                                value: order.customerPhone!,
                              ),
                            ],
                            const SizedBox(height: 8),
                            _AccountInfoRow(
                              label: 'Assigned to',
                              value: order.employeeName,
                            ),
                            const SizedBox(height: 8),
                            _AccountInfoRow(
                              label: 'Ordered at',
                              value: _formatBookingDateTime(order.scheduledAt),
                            ),
                            const SizedBox(height: 8),
                            _AccountInfoRow(
                              label: 'Type',
                              value: order.visitMode,
                            ),
                            if ((order.address ?? '')
                                .trim()
                                .isNotEmpty) ...<Widget>[
                              const SizedBox(height: 8),
                              _AccountInfoRow(
                                label: 'Address',
                                value: order.address!,
                              ),
                            ],
                            const SizedBox(height: 8),
                            _AccountInfoRow(
                              label: 'Total',
                              value: formatBhd(order.total),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Open details',
                                style: TextStyle(
                                  color: AppPalette.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              if (showAppointments) const SizedBox(height: 20),
            ],
            if (showAppointments) ...<Widget>[
              Text(
                'Service Bookings',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.foreground,
                ),
              ),
              const SizedBox(height: 12),
              if (filteredBookings.isEmpty)
                _EmptyStateCard(
                  icon: Icons.event_busy_rounded,
                  title: 'No bookings found',
                  message: hasSearchQuery
                      ? 'No appointments match the current search.'
                      : 'Customer appointments will appear here once your salon starts receiving bookings.',
                )
              else
                ...filteredBookings.map((UserOrder order) {
                  final bool completed = _isManagementOrderCompleted(order);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => unawaited(openBooking(order)),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: appCardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    order.serviceName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: completed
                                        ? AppPalette.secondary
                                        : AppPalette.primary.withValues(
                                            alpha: 0.12,
                                          ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    order.statusLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: completed
                                          ? AppPalette.foreground
                                          : AppPalette.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _AccountInfoRow(
                              label: 'Invoice',
                              value: order.displayInvoiceNumber,
                            ),
                            const SizedBox(height: 8),
                            _AccountInfoRow(
                              label: 'Customer',
                              value: order.customerName ?? 'Freshline Customer',
                            ),
                            if ((order.customerPhone ?? '')
                                .trim()
                                .isNotEmpty) ...<Widget>[
                              const SizedBox(height: 8),
                              _AccountInfoRow(
                                label: 'Phone',
                                value: order.customerPhone!,
                              ),
                            ],
                            const SizedBox(height: 8),
                            _AccountInfoRow(
                              label: 'Employee',
                              value: order.employeeName,
                            ),
                            const SizedBox(height: 8),
                            _AccountInfoRow(
                              label: 'Time',
                              value: _formatBookingDateTime(order.scheduledAt),
                            ),
                            const SizedBox(height: 8),
                            _AccountInfoRow(
                              label: 'Visit',
                              value: order.visitMode,
                            ),
                            if ((order.address ?? '')
                                .trim()
                                .isNotEmpty) ...<Widget>[
                              const SizedBox(height: 8),
                              _AccountInfoRow(
                                label: 'Address',
                                value: order.address!,
                              ),
                            ],
                            const SizedBox(height: 8),
                            _AccountInfoRow(
                              label: 'Total',
                              value: formatBhd(order.total),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Open details',
                                style: TextStyle(
                                  color: AppPalette.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ],
        ],
      ),
    );
  }
}

class ManagementSalonBookingDetailsScreen extends StatelessWidget {
  const ManagementSalonBookingDetailsScreen({super.key, required this.order});

  final UserOrder order;

  @override
  Widget build(BuildContext context) {
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: const Text('Appointment Details')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          order.serviceName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _isManagementOrderCompleted(order)
                              ? AppPalette.secondary
                              : AppPalette.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          order.statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _isManagementOrderCompleted(order)
                                ? AppPalette.foreground
                                : AppPalette.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    label: 'Invoice',
                    value: order.displayInvoiceNumber,
                  ),
                  _SummaryRow(label: 'Salon', value: order.salonName),
                  _SummaryRow(
                    label: 'Customer',
                    value: order.customerName ?? 'Freshline Customer',
                  ),
                  _SummaryRow(
                    label: 'Phone',
                    value: (order.customerPhone ?? '').trim().isEmpty
                        ? '-'
                        : order.customerPhone!,
                  ),
                  _SummaryRow(label: 'Employee', value: order.employeeName),
                  _SummaryRow(
                    label: 'Appointment',
                    value: _formatBookingDateTime(order.scheduledAt),
                  ),
                  _SummaryRow(label: 'Visit mode', value: order.visitMode),
                  if (order.appointmentDuration != null)
                    _SummaryRow(
                      label: 'Duration',
                      value: '${order.appointmentDuration!.inMinutes} min',
                    ),
                  if ((order.address ?? '').trim().isNotEmpty)
                    _SummaryRow(label: 'Address', value: order.address!),
                  if ((order.addressDetails ?? '').trim().isNotEmpty)
                    _SummaryRow(
                      label: 'Location details',
                      value: order.addressDetails!,
                    ),
                  if ((order.cardLabel ?? '').trim().isNotEmpty)
                    _SummaryRow(label: 'Payment', value: order.cardLabel!),
                  _SummaryRow(
                    label: 'Points earned',
                    value: '${order.loyaltyPointsGained} pts',
                  ),
                  _SummaryRow(
                    label: 'Total',
                    value: formatBhd(order.total),
                    prominent: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ManagementProductOrderDetailsScreen extends StatefulWidget {
  const ManagementProductOrderDetailsScreen({
    super.key,
    required this.actor,
    required this.platformRepository,
    required this.order,
  });

  final AppUser actor;
  final PlatformRepository platformRepository;
  final UserOrder order;

  @override
  State<ManagementProductOrderDetailsScreen> createState() =>
      _ManagementProductOrderDetailsScreenState();
}

class _ManagementProductOrderDetailsScreenState
    extends State<ManagementProductOrderDetailsScreen> {
  bool _isSubmitting = false;

  bool get _isCompleted => _isManagementOrderCompleted(widget.order);
  bool get _isEmployee => widget.actor.role == AppRole.employee;
  bool get _isOwner => widget.actor.role == AppRole.salonOwner;
  bool get _isAdmin => widget.actor.role == AppRole.admin;

  Future<void> _takeOrder() async {
    final bool shouldContinue = await _showActionConfirmationDialog(
      context: context,
      title: 'Take Product Order',
      message: _isAdmin
          ? 'This product order will be assigned to you and hidden from the other admins.'
          : 'This product order will be assigned to you and hidden from the other employees.',
      confirmLabel: 'Take Order',
    );
    if (!shouldContinue) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (_isAdmin) {
        await widget.platformRepository.takeAdminProductOrder(
          actor: widget.actor,
          orderId: widget.order.id,
        );
      } else {
        await widget.platformRepository.takeSalonProductOrder(
          actor: widget.actor,
          orderId: widget.order.id,
        );
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _markDelivered() async {
    final bool shouldContinue = await _showActionConfirmationDialog(
      context: context,
      title: 'Mark Order Delivered',
      message:
          'This product order will be marked as delivered for the customer.',
      confirmLabel: 'Mark Delivered',
    );
    if (!shouldContinue) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.platformRepository.completeOrder(
        user: widget.actor,
        order: widget.order,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final UserOrder order = widget.order;
    final bool canTake =
        (_isEmployee || _isAdmin) &&
        order.isUnassignedProductOrder &&
        !_isCompleted;
    final bool canComplete =
        !_isCompleted &&
        (_isOwner ||
            _isAdmin ||
            (_isEmployee && !order.isUnassignedProductOrder));

    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: const Text('Product Order Details')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          order.serviceName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _isCompleted
                              ? AppPalette.secondary
                              : order.isUnassignedProductOrder
                              ? const Color(0xFFD97706).withValues(alpha: 0.14)
                              : AppPalette.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          order.isUnassignedProductOrder && !_isCompleted
                              ? 'Available'
                              : order.statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _isCompleted
                                ? AppPalette.foreground
                                : order.isUnassignedProductOrder
                                ? const Color(0xFFD97706)
                                : AppPalette.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SummaryRow(
                    label: 'Invoice',
                    value: order.displayInvoiceNumber,
                  ),
                  _SummaryRow(
                    label: 'Customer',
                    value: order.customerName ?? 'Freshline Customer',
                  ),
                  _SummaryRow(
                    label: 'Phone',
                    value: (order.customerPhone ?? '').trim().isEmpty
                        ? '-'
                        : order.customerPhone!,
                  ),
                  _SummaryRow(
                    label: 'Ordered at',
                    value: _formatBookingDateTime(order.scheduledAt),
                  ),
                  _SummaryRow(label: 'Type', value: order.visitMode),
                  _SummaryRow(label: 'Assigned to', value: order.employeeName),
                  _SummaryRow(label: 'Total', value: formatBhd(order.total)),
                  if ((order.cardLabel ?? '').trim().isNotEmpty)
                    _SummaryRow(label: 'Payment', value: order.cardLabel!),
                  if ((order.address ?? '').trim().isNotEmpty)
                    _SummaryRow(label: 'Address', value: order.address!),
                  if ((order.addressDetails ?? '').trim().isNotEmpty)
                    _SummaryRow(
                      label: 'Location',
                      value: order.addressDetails!,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Order Items',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  if (order.productItems.isEmpty)
                    Text(
                      'No product line items were saved for this order.',
                      style: TextStyle(color: AppPalette.mutedForeground),
                    )
                  else
                    ...order.productItems.map((RatedOrderProductItem item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: appCardDecoration(
                            color: AppPalette.background,
                            radius: 20,
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      item.productName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item.quantity} x ${formatBhd(item.unitPrice)}',
                                      style: TextStyle(
                                        color: AppPalette.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                formatBhd(item.lineTotal),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
            if (canTake || canComplete) ...<Widget>[
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  if (canTake)
                    Expanded(
                      child: FilledButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => unawaited(_takeOrder()),
                        child: const Text('Take Order'),
                      ),
                    ),
                  if (canTake && canComplete) const SizedBox(width: 12),
                  if (canComplete)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => unawaited(_markDelivered()),
                        child: const Text('Mark Delivered'),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SalonOwnerTeamScreen extends StatefulWidget {
  const SalonOwnerTeamScreen({
    super.key,
    required this.actor,
    required this.platformRepository,
    required this.workspace,
    required this.isLoading,
    required this.onRefresh,
  });

  final AppUser actor;
  final PlatformRepository platformRepository;
  final SalonWorkspaceSnapshot? workspace;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  @override
  State<SalonOwnerTeamScreen> createState() => _SalonOwnerTeamScreenState();
}

class _SalonOwnerTeamScreenState extends State<SalonOwnerTeamScreen> {
  Future<void> _openEditor({Employee? employee}) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => SalonEmployeeEditorScreen(
          actor: widget.actor,
          platformRepository: widget.platformRepository,
          employee: employee,
        ),
      ),
    );
    if (changed == true) {
      await widget.onRefresh();
    }
  }

  Future<void> _openDetails(Employee employee) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => SalonEmployeeDetailsScreen(
          actor: widget.actor,
          platformRepository: widget.platformRepository,
          employee: employee,
        ),
      ),
    );
    if (changed == true) {
      await widget.onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final SalonWorkspaceSnapshot? workspace = widget.workspace;
    if (widget.isLoading && workspace == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (workspace == null) {
      return SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          child: _EmptyStateCard(
            icon: Icons.group_outlined,
            title: 'No employees loaded',
            message:
                'Refresh the salon workspace to manage your employee accounts.',
            actionLabel: 'Refresh',
            onAction: () => unawaited(widget.onRefresh()),
          ),
        ),
      );
    }

    final List<Employee> employees = List<Employee>.from(workspace.employees)
      ..sort((Employee a, Employee b) {
        if (a.isActive != b.isActive) {
          return a.isActive ? -1 : 1;
        }
        return a.name.compareTo(b.name);
      });
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: <Widget>[
          const Text(
            'Employees',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: appCardDecoration(),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => unawaited(widget.onRefresh()),
                    child: const Text('Refresh'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => unawaited(_openEditor()),
                    child: const Text('Add Employee'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...employees.map((Employee employee) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => unawaited(_openDetails(employee)),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: appCardDecoration(),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          _ManagementAvatar(
                            imagePath: employee.imagePath,
                            radius: 28,
                            icon: Icons.badge_rounded,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  employee.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  employee.role,
                                  style: TextStyle(
                                    color: AppPalette.mutedForeground,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  employee.isActive
                                      ? 'Account active'
                                      : 'Account paused',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: employee.isActive
                                        ? AppPalette.primary
                                        : AppPalette.mutedForeground,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: AppPalette.mutedForeground,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _TagCard(
                              label:
                                  '${employee.rating.toStringAsFixed(1)} (${employee.reviewsCount})',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _TagCard(
                              label: formatBhd(employee.monthlySalary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _TagCard(
                              label: employee.supportsHomeService
                                  ? 'Home service'
                                  : 'In-shop only',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _TagCard(
                              label: employee.canLogin
                                  ? 'Login enabled'
                                  : 'No login',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _AccountInfoRow(
                        label: 'Contact',
                        value: employee.phone.isEmpty
                            ? employee.email
                            : '${employee.phone} · ${employee.email}',
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class SalonOwnerCatalogScreen extends StatefulWidget {
  const SalonOwnerCatalogScreen({
    super.key,
    required this.actor,
    required this.platformRepository,
    required this.workspace,
    required this.isLoading,
    required this.onRefresh,
  });

  final AppUser actor;
  final PlatformRepository platformRepository;
  final SalonWorkspaceSnapshot? workspace;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  @override
  State<SalonOwnerCatalogScreen> createState() =>
      _SalonOwnerCatalogScreenState();
}

class _SalonOwnerCatalogScreenState extends State<SalonOwnerCatalogScreen> {
  bool _isSubmitting = false;

  Future<void> _openPackageEditor([ServicePackage? existing]) async {
    final _SalonCatalogDraft? draft = await Navigator.of(context)
        .push<_SalonCatalogDraft>(
          MaterialPageRoute<_SalonCatalogDraft>(
            builder: (BuildContext context) => SalonCatalogEditorScreen(
              title: existing == null
                  ? _tr(context, 'Add Package', 'إضافة باقة')
                  : _tr(context, 'Edit Package', 'تعديل الباقة'),
              name: existing?.localizedName(context) ?? '',
              description: existing?.localizedDescription(context) ?? '',
              price: existing == null ? '' : formatPrice(existing.price),
              durationMinutes: _durationMinutesFromLabel(existing?.duration),
              isActive: existing?.isActive ?? true,
              submitLabel: existing == null
                  ? _tr(context, 'Create Package', 'إنشاء باقة')
                  : _tr(context, 'Save Package', 'حفظ الباقة'),
            ),
          ),
        );
    if (draft == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.platformRepository.saveSalonPackage(
        actor: widget.actor,
        packageId: existing?.id,
        name: draft.name,
        description: draft.description,
        price: draft.price,
        durationMinutes: draft.durationMinutes,
        isActive: draft.isActive,
      );
      if (!mounted) {
        return;
      }
      await widget.onRefresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? _tr(
                    context,
                    'Package created successfully.',
                    'تم إنشاء الباقة بنجاح.',
                  )
                : _tr(
                    context,
                    'Package updated successfully.',
                    'تم تحديث الباقة بنجاح.',
                  ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _deletePackage(ServicePackage item) async {
    final bool shouldDelete = await _showActionConfirmationDialog(
      context: context,
      title: _tr(context, 'Delete Package', 'حذف الباقة'),
      message: _tr(
        context,
        'Remove ${item.localizedName(context)} from the salon packages list?',
        'هل تريد حذف ${item.localizedName(context)} من قائمة باقات الصالون؟',
      ),
      confirmLabel: _tr(context, 'Delete', 'حذف'),
      isDestructive: true,
    );
    if (!shouldDelete) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.platformRepository.deleteSalonPackage(
        actor: widget.actor,
        packageId: item.id,
      );
      if (!mounted) {
        return;
      }
      await widget.onRefresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _openServiceEditor([ServiceItem? existing]) async {
    final _SalonCatalogDraft? draft = await Navigator.of(context)
        .push<_SalonCatalogDraft>(
          MaterialPageRoute<_SalonCatalogDraft>(
            builder: (BuildContext context) => SalonCatalogEditorScreen(
              title: existing == null
                  ? _tr(context, 'Add Service', 'إضافة خدمة')
                  : _tr(context, 'Edit Service', 'تعديل الخدمة'),
              name: existing?.localizedName(context) ?? '',
              description: existing?.localizedDescription(context) ?? '',
              price: existing == null ? '' : formatPrice(existing.price),
              durationMinutes: _durationMinutesFromLabel(existing?.duration),
              isActive: existing?.isActive ?? true,
              submitLabel: existing == null
                  ? _tr(context, 'Create Service', 'إنشاء خدمة')
                  : _tr(context, 'Save Service', 'حفظ الخدمة'),
            ),
          ),
        );
    if (draft == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.platformRepository.saveSalonService(
        actor: widget.actor,
        serviceId: existing?.id,
        name: draft.name,
        description: draft.description,
        price: draft.price,
        durationMinutes: draft.durationMinutes,
        isActive: draft.isActive,
      );
      if (!mounted) {
        return;
      }
      await widget.onRefresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? _tr(
                    context,
                    'Service created successfully.',
                    'تم إنشاء الخدمة بنجاح.',
                  )
                : _tr(
                    context,
                    'Service updated successfully.',
                    'تم تحديث الخدمة بنجاح.',
                  ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _deleteService(ServiceItem item) async {
    final bool shouldDelete = await _showActionConfirmationDialog(
      context: context,
      title: _tr(context, 'Delete Service', 'حذف الخدمة'),
      message: _tr(
        context,
        'Remove ${item.localizedName(context)} from the salon services list?',
        'هل تريد حذف ${item.localizedName(context)} من قائمة خدمات الصالون؟',
      ),
      confirmLabel: _tr(context, 'Delete', 'حذف'),
      isDestructive: true,
    );
    if (!shouldDelete) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.platformRepository.deleteSalonService(
        actor: widget.actor,
        serviceId: item.id,
      );
      if (!mounted) {
        return;
      }
      await widget.onRefresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _openProductEditor([Product? existing]) async {
    final _SalonProductDraft? draft = await Navigator.of(context)
        .push<_SalonProductDraft>(
          MaterialPageRoute<_SalonProductDraft>(
            builder: (BuildContext context) => SalonProductEditorScreen(
              platformRepository: widget.platformRepository,
              title: existing == null
                  ? _tr(context, 'Add Product', 'إضافة منتج')
                  : _tr(context, 'Edit Product', 'تعديل المنتج'),
              name: existing?.localizedName(context) ?? '',
              category: existing?.localizedCategory(context) ?? '',
              description: existing?.localizedDescription(context) ?? '',
              price: existing == null ? '' : formatPrice(existing.price),
              stock: existing == null ? '0' : '${existing.stock}',
              isActive: existing?.isActive ?? true,
              initialImagePath:
                  existing?.imagePath ?? currentDefaultProductImageUrl(),
              submitLabel: existing == null
                  ? _tr(context, 'Create Product', 'إنشاء منتج')
                  : _tr(context, 'Save Product', 'حفظ المنتج'),
            ),
          ),
        );
    if (draft == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.platformRepository.saveSalonProduct(
        actor: widget.actor,
        productId: existing?.id,
        name: draft.name,
        category: draft.category,
        description: draft.description,
        price: draft.price,
        stock: draft.stock,
        isActive: draft.isActive,
        imagePath: draft.imagePath,
      );
      if (!mounted) {
        return;
      }
      await widget.onRefresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? _tr(
                    context,
                    'Product created successfully.',
                    'تم إنشاء المنتج بنجاح.',
                  )
                : _tr(
                    context,
                    'Product updated successfully.',
                    'تم تحديث المنتج بنجاح.',
                  ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _deleteProduct(Product item) async {
    final bool shouldDelete = await _showActionConfirmationDialog(
      context: context,
      title: _tr(context, 'Delete Product', 'حذف المنتج'),
      message: _tr(
        context,
        'Remove ${item.localizedName(context)} from the salon products list?',
        'هل تريد حذف ${item.localizedName(context)} من قائمة منتجات الصالون؟',
      ),
      confirmLabel: _tr(context, 'Delete', 'حذف'),
      isDestructive: true,
    );
    if (!shouldDelete) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.platformRepository.deleteSalonProduct(
        actor: widget.actor,
        productId: item.id,
      );
      if (!mounted) {
        return;
      }
      await widget.onRefresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final SalonWorkspaceSnapshot? workspace = widget.workspace;
    if (widget.isLoading && workspace == null) {
      return const AppViewport(
        child: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    if (workspace == null) {
      return AppViewport(
        child: Scaffold(
          appBar: AppBar(title: const Text('Catalog')),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: _EmptyStateCard(
              icon: Icons.spa_outlined,
              title: 'Catalog is not ready',
              message:
                  'Refresh the salon workspace to manage packages, services, and products.',
              actionLabel: 'Refresh',
              onAction: () => unawaited(widget.onRefresh()),
            ),
          ),
        ),
      );
    }

    final List<ServicePackage> packages =
        List<ServicePackage>.from(workspace.packages)..sort(
          (ServicePackage a, ServicePackage b) =>
              a.localizedName(context).compareTo(b.localizedName(context)),
        );
    final List<ServiceItem> services =
        List<ServiceItem>.from(workspace.services)..sort(
          (ServiceItem a, ServiceItem b) =>
              a.localizedName(context).compareTo(b.localizedName(context)),
        );
    final List<Product> products = List<Product>.from(workspace.products)
      ..sort(
        (Product a, Product b) =>
            a.localizedName(context).compareTo(b.localizedName(context)),
      );
    final int activePackages = packages
        .where((ServicePackage item) => item.isActive)
        .length;
    final int activeServices = services
        .where((ServiceItem item) => item.isActive)
        .length;
    final int activeProducts = products
        .where((Product item) => item.isActive)
        .length;
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: const Text('Catalog')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              workspace.salon.localizedName(context),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Manage the three customer-facing catalog areas from one place: packages, services, and products.',
                              style: TextStyle(
                                height: 1.45,
                                color: AppPalette.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => unawaited(widget.onRefresh()),
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  if (_isSubmitting) ...<Widget>[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(minHeight: 3),
                  ],
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final bool compact = constraints.maxWidth < 620;
                          final double tileWidth = compact
                              ? (constraints.maxWidth - 12) / 2
                              : (constraints.maxWidth - 24) / 3;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: <Widget>[
                              SizedBox(
                                width: tileWidth,
                                child: _CatalogSummaryTile(
                                  icon: Icons.inventory_2_outlined,
                                  label: 'Packages',
                                  value: '${packages.length}',
                                  detail: '$activePackages active',
                                ),
                              ),
                              SizedBox(
                                width: tileWidth,
                                child: _CatalogSummaryTile(
                                  icon: Icons.content_cut_rounded,
                                  label: 'Services',
                                  value: '${services.length}',
                                  detail: '$activeServices active',
                                ),
                              ),
                              SizedBox(
                                width: tileWidth,
                                child: _CatalogSummaryTile(
                                  icon: Icons.shopping_bag_outlined,
                                  label: 'Products',
                                  value: '${products.length}',
                                  detail: '$activeProducts active',
                                ),
                              ),
                            ],
                          );
                        },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _CatalogBoardSection(
              title: 'Packages',
              subtitle:
                  'Bundle treatments into stronger booking options for customers.',
              icon: Icons.inventory_2_outlined,
              countLabel: '${packages.length} total',
              actionLabel: 'Add Package',
              onAction: _isSubmitting
                  ? null
                  : () => unawaited(_openPackageEditor()),
              children: _buildPackageCards(packages),
            ),
            const SizedBox(height: 12),
            _CatalogBoardSection(
              title: 'Services',
              subtitle:
                  'Keep individual services clear, simple, and easy to update.',
              icon: Icons.content_cut_rounded,
              countLabel: '${services.length} total',
              actionLabel: 'Add Service',
              onAction: _isSubmitting
                  ? null
                  : () => unawaited(_openServiceEditor()),
              children: _buildServiceCards(services),
            ),
            const SizedBox(height: 12),
            _CatalogBoardSection(
              title: 'Products',
              subtitle:
                  'Show the available retail products that this salon owner wants customers to see.',
              icon: Icons.shopping_bag_outlined,
              countLabel: '${products.length} total',
              actionLabel: 'Add Product',
              onAction: _isSubmitting
                  ? null
                  : () => unawaited(_openProductEditor()),
              children: _buildProductCards(products),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPackageCards(List<ServicePackage> packages) {
    if (packages.isEmpty) {
      return const <Widget>[
        _EmptyStateCard(
          icon: Icons.inventory_2_outlined,
          title: 'No packages yet',
          message:
              'Add bundled packages with pricing and duration for your salon.',
        ),
      ];
    }
    return packages
        .map((ServicePackage item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _CatalogLeadingIcon(
                        icon: Icons.inventory_2_outlined,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.localizedName(context),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.isActive
                                  ? 'Visible in the salon booking flow.'
                                  : 'Hidden from the salon booking flow.',
                              style: TextStyle(
                                fontSize: 12,
                                color: item.isActive
                                    ? AppPalette.primary
                                    : AppPalette.mutedForeground,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _CatalogStatusChip(
                        label: item.isActive ? 'Live' : 'Hidden',
                        backgroundColor: item.isActive
                            ? AppPalette.primary.withValues(alpha: 0.14)
                            : AppPalette.secondary,
                        foregroundColor: item.isActive
                            ? AppPalette.primary
                            : AppPalette.mutedForeground,
                      ),
                    ],
                  ),
                  if (item
                      .localizedDescription(context)
                      .trim()
                      .isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      item.localizedDescription(context),
                      style: TextStyle(
                        height: 1.45,
                        color: AppPalette.mutedForeground,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _CatalogMetaChip(
                        icon: Icons.schedule_rounded,
                        label: item.localizedDuration(context),
                      ),
                      _CatalogMetaChip(
                        icon: Icons.payments_outlined,
                        label: formatBhd(item.price),
                        emphasized: true,
                      ),
                      _CatalogMetaChip(
                        icon: item.isActive
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        label: item.isActive ? 'Customer visible' : 'Hidden',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : () => unawaited(_openPackageEditor(item)),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : () => unawaited(_deletePackage(item)),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Remove'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        })
        .toList(growable: false);
  }

  List<Widget> _buildServiceCards(List<ServiceItem> services) {
    if (services.isEmpty) {
      return const <Widget>[
        _EmptyStateCard(
          icon: Icons.content_cut_rounded,
          title: 'No services yet',
          message:
              'Add individual services so customers can book them one by one.',
        ),
      ];
    }
    return services
        .map((ServiceItem item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _CatalogLeadingIcon(
                        icon: Icons.content_cut_rounded,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.localizedName(context),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.isActive
                                  ? 'Bookable now for Freshline customers.'
                                  : 'Hidden until you enable it again.',
                              style: TextStyle(
                                fontSize: 12,
                                color: item.isActive
                                    ? AppPalette.primary
                                    : AppPalette.mutedForeground,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _CatalogStatusChip(
                        label: item.isActive ? 'Live' : 'Hidden',
                        backgroundColor: item.isActive
                            ? AppPalette.primary.withValues(alpha: 0.14)
                            : AppPalette.secondary,
                        foregroundColor: item.isActive
                            ? AppPalette.primary
                            : AppPalette.mutedForeground,
                      ),
                    ],
                  ),
                  if (item
                      .localizedDescription(context)
                      .trim()
                      .isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      item.localizedDescription(context),
                      style: TextStyle(
                        height: 1.45,
                        color: AppPalette.mutedForeground,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _CatalogMetaChip(
                        icon: Icons.schedule_rounded,
                        label: item.localizedDuration(context),
                      ),
                      _CatalogMetaChip(
                        icon: Icons.payments_outlined,
                        label: formatBhd(item.price),
                        emphasized: true,
                      ),
                      _CatalogMetaChip(
                        icon: item.isActive
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        label: item.isActive ? 'Customer visible' : 'Hidden',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : () => unawaited(_openServiceEditor(item)),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : () => unawaited(_deleteService(item)),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Remove'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        })
        .toList(growable: false);
  }

  List<Widget> _buildProductCards(List<Product> products) {
    if (products.isEmpty) {
      return const <Widget>[
        _EmptyStateCard(
          icon: Icons.shopping_bag_outlined,
          title: 'No products yet',
          message:
              'Add salon retail products with price, stock, and category so the catalog stays complete.',
        ),
      ];
    }
    return products
        .map((Product item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _CatalogLeadingIcon(
                        icon: Icons.shopping_bag_outlined,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              item.localizedName(context),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.isActive
                                  ? 'Visible in the retail catalog.'
                                  : 'Hidden from the retail catalog.',
                              style: TextStyle(
                                fontSize: 12,
                                color: item.isActive
                                    ? AppPalette.primary
                                    : AppPalette.mutedForeground,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _CatalogStatusChip(
                        label: item.isActive ? 'Live' : 'Hidden',
                        backgroundColor: item.isActive
                            ? AppPalette.primary.withValues(alpha: 0.14)
                            : AppPalette.secondary,
                        foregroundColor: item.isActive
                            ? AppPalette.primary
                            : AppPalette.mutedForeground,
                      ),
                    ],
                  ),
                  if (item
                      .localizedDescription(context)
                      .trim()
                      .isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      item.localizedDescription(context),
                      style: TextStyle(
                        height: 1.45,
                        color: AppPalette.mutedForeground,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      _CatalogMetaChip(
                        icon: Icons.category_outlined,
                        label: item.localizedCategory(context),
                      ),
                      _CatalogMetaChip(
                        icon: Icons.inventory_2_outlined,
                        label: 'Stock ${item.stock}',
                      ),
                      _CatalogMetaChip(
                        icon: Icons.payments_outlined,
                        label: formatBhd(item.price),
                        emphasized: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : () => unawaited(_openProductEditor(item)),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : () => unawaited(_deleteProduct(item)),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Remove'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        })
        .toList(growable: false);
  }
}

class _CatalogBoardSection extends StatelessWidget {
  const _CatalogBoardSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.actionLabel,
    this.countLabel,
    this.children = const <Widget>[],
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String actionLabel;
  final String? countLabel;
  final List<Widget> children;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: appCardDecoration(color: AppPalette.card, radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _CatalogLeadingIcon(icon: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (countLabel != null)
                          _CatalogStatusChip(
                            label: countLabel!,
                            backgroundColor: AppPalette.secondary,
                            foregroundColor: AppPalette.mutedForeground,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        height: 1.4,
                        color: AppPalette.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _CatalogSummaryTile extends StatelessWidget {
  const _CatalogSummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: appCardDecoration(color: AppPalette.background, radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: AppPalette.primary, size: 18),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppPalette.mutedForeground),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: TextStyle(
              fontSize: 12,
              color: AppPalette.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogLeadingIcon extends StatelessWidget {
  const _CatalogLeadingIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppPalette.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: AppPalette.primary),
    );
  }
}

class _CatalogStatusChip extends StatelessWidget {
  const _CatalogStatusChip({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _localizedDisplayText(context, label),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );
  }
}

class _CatalogMetaChip extends StatelessWidget {
  const _CatalogMetaChip({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = emphasized
        ? AppPalette.primary.withValues(alpha: 0.12)
        : AppPalette.background;
    final Color foregroundColor = emphasized
        ? AppPalette.primary
        : AppPalette.foreground;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: emphasized
              ? AppPalette.primary.withValues(alpha: 0.24)
              : AppPalette.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: foregroundColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _localizedDisplayText(context, label),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: foregroundColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalonCatalogDraft {
  const _SalonCatalogDraft({
    required this.name,
    required this.description,
    required this.price,
    required this.durationMinutes,
    required this.isActive,
  });

  final String name;
  final String description;
  final double price;
  final int durationMinutes;
  final bool isActive;
}

class _SalonProductDraft {
  const _SalonProductDraft({
    required this.name,
    required this.category,
    required this.description,
    required this.price,
    required this.stock,
    required this.isActive,
    required this.imagePath,
  });

  final String name;
  final String category;
  final String description;
  final double price;
  final int stock;
  final bool isActive;
  final String imagePath;
}

class SalonCatalogEditorScreen extends StatefulWidget {
  const SalonCatalogEditorScreen({
    super.key,
    required this.title,
    required this.name,
    required this.description,
    required this.price,
    required this.durationMinutes,
    required this.isActive,
    required this.submitLabel,
  });

  final String title;
  final String name;
  final String description;
  final String price;
  final int? durationMinutes;
  final bool isActive;
  final String submitLabel;

  @override
  State<SalonCatalogEditorScreen> createState() =>
      _SalonCatalogEditorScreenState();
}

class _SalonCatalogEditorScreenState extends State<SalonCatalogEditorScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController(
    text: widget.name,
  );
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.description);
  late final TextEditingController _priceController = TextEditingController(
    text: widget.price,
  );
  late final TextEditingController _durationController = TextEditingController(
    text: widget.durationMinutes?.toString() ?? '',
  );
  late bool _isActive = widget.isActive;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(
      _SalonCatalogDraft(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        durationMinutes: int.parse(_durationController.text.trim()),
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool editing = widget.name.trim().isNotEmpty;
    final bool isPackage = widget.title.toLowerCase().contains('package');
    final String itemLabel = isPackage ? 'package' : 'service';
    final String itemDescription = isPackage
        ? 'Packages help customers book bundled salon experiences in one clear step.'
        : 'Services stay visible as individual bookable items in your salon flow.';

    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: <Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: appCardDecoration(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _CatalogLeadingIcon(
                      icon: isPackage
                          ? Icons.inventory_2_outlined
                          : Icons.content_cut_rounded,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            editing
                                ? 'Update this salon $itemLabel'
                                : 'Create a new salon $itemLabel',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            itemDescription,
                            style: TextStyle(
                              height: 1.45,
                              color: AppPalette.mutedForeground,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _CatalogStatusChip(
                            label: _isActive
                                ? 'Visible to customers'
                                : 'Hidden',
                            backgroundColor: _isActive
                                ? AppPalette.primary.withValues(alpha: 0.14)
                                : AppPalette.secondary,
                            foregroundColor: _isActive
                                ? AppPalette.primary
                                : AppPalette.mutedForeground,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: appCardDecoration(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _AuthTextField(
                        controller: _nameController,
                        label: 'Name',
                        onChanged: (_) => setState(() {}),
                        validator: (String? value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Enter a name.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _AuthTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _AuthTextField(
                              controller: _priceController,
                              label: 'Price BHD',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (_) => setState(() {}),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]'),
                                ),
                              ],
                              validator: (String? value) {
                                final double? price = double.tryParse(
                                  (value ?? '').trim(),
                                );
                                if (price == null || price <= 0) {
                                  return 'Enter a valid price.';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _AuthTextField(
                              controller: _durationController,
                              label: 'Duration Min',
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              validator: (String? value) {
                                final int? minutes = int.tryParse(
                                  (value ?? '').trim(),
                                );
                                if (minutes == null || minutes <= 0) {
                                  return 'Enter minutes.';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: appCardDecoration(
                          color: AppPalette.background,
                          radius: 22,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'Preview',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: <Widget>[
                                _CatalogMetaChip(
                                  icon: Icons.label_outline_rounded,
                                  label: _nameController.text.trim().isEmpty
                                      ? 'Set a name'
                                      : _nameController.text.trim(),
                                ),
                                _CatalogMetaChip(
                                  icon: Icons.payments_outlined,
                                  label: _priceController.text.trim().isEmpty
                                      ? 'Set price'
                                      : 'BHD ${_priceController.text.trim()}',
                                  emphasized: _priceController.text
                                      .trim()
                                      .isNotEmpty,
                                ),
                                _CatalogMetaChip(
                                  icon: Icons.schedule_rounded,
                                  label: _durationController.text.trim().isEmpty
                                      ? 'Set duration'
                                      : '${_durationController.text.trim()} min',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile.adaptive(
                        value: _isActive,
                        onChanged: (bool value) {
                          setState(() => _isActive = value);
                        },
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        subtitle: Text(
                          isPackage
                              ? 'Active packages appear in the salon booking experience.'
                              : 'Active services appear in the salon booking experience.',
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _save,
                          child: Text(widget.submitLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SalonProductEditorScreen extends StatefulWidget {
  const SalonProductEditorScreen({
    super.key,
    required this.platformRepository,
    required this.title,
    required this.name,
    required this.category,
    required this.description,
    required this.price,
    required this.stock,
    required this.isActive,
    required this.initialImagePath,
    required this.submitLabel,
  });

  final PlatformRepository platformRepository;
  final String title;
  final String name;
  final String category;
  final String description;
  final String price;
  final String stock;
  final bool isActive;
  final String initialImagePath;
  final String submitLabel;

  @override
  State<SalonProductEditorScreen> createState() =>
      _SalonProductEditorScreenState();
}

class _SalonProductEditorScreenState extends State<SalonProductEditorScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController(
    text: widget.name,
  );
  late final TextEditingController _categoryController = TextEditingController(
    text: widget.category,
  );
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.description);
  late final TextEditingController _priceController = TextEditingController(
    text: widget.price,
  );
  late final TextEditingController _stockController = TextEditingController(
    text: widget.stock,
  );
  late bool _isActive = widget.isActive;
  late String _imagePath = widget.initialImagePath.trim().isEmpty
      ? currentDefaultProductImageUrl()
      : widget.initialImagePath.trim();
  bool _isUploadingImage = false;
  late final String _draftProductImageKey = widget.name.trim().isEmpty
      ? 'product-${DateTime.now().millisecondsSinceEpoch}'
      : widget.name.trim();

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  String get _productImageKey {
    final String name = _nameController.text.trim();
    if (name.isNotEmpty) {
      return name;
    }
    return _draftProductImageKey;
  }

  Future<void> _uploadProductImage() async {
    setState(() => _isUploadingImage = true);
    try {
      final String? uploadedPath = await widget.platformRepository
          .pickAndUploadSalonProductImage(productKey: _productImageKey);
      if (!mounted || uploadedPath == null || uploadedPath.trim().isEmpty) {
        return;
      }
      setState(() => _imagePath = uploadedPath.trim());
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(
      _SalonProductDraft(
        name: _nameController.text.trim(),
        category: _categoryController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        stock: int.parse(_stockController.text.trim()),
        isActive: _isActive,
        imagePath: _imagePath.trim().isEmpty
            ? currentDefaultProductImageUrl()
            : _imagePath.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool editing = widget.name.trim().isNotEmpty;

    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            children: <Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: appCardDecoration(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const _CatalogLeadingIcon(
                      icon: Icons.shopping_bag_outlined,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            editing
                                ? 'Update this catalog product'
                                : 'Create a new catalog product',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Use the same clean management style as the employee and coupon tools, with product details ready for the owner catalog.',
                            style: TextStyle(
                              height: 1.45,
                              color: AppPalette.mutedForeground,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _CatalogStatusChip(
                            label: _isActive
                                ? 'Visible to customers'
                                : 'Hidden',
                            backgroundColor: _isActive
                                ? AppPalette.primary.withValues(alpha: 0.14)
                                : AppPalette.secondary,
                            foregroundColor: _isActive
                                ? AppPalette.primary
                                : AppPalette.mutedForeground,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: appCardDecoration(),
                child: Column(
                  children: <Widget>[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: _AppImage(
                        imagePath: _imagePath,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Product image',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Upload a product image or keep the Freshline default image for this item.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppPalette.mutedForeground,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUploadingImage
                                ? null
                                : _uploadProductImage,
                            icon: _isUploadingImage
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.photo_camera_outlined),
                            label: Text(
                              isDefaultProductImageSelection(_imagePath)
                                  ? 'Upload Photo'
                                  : 'Replace Photo',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextButton(
                            onPressed: _isUploadingImage
                                ? null
                                : () {
                                    setState(
                                      () => _imagePath =
                                          currentDefaultProductImageUrl(),
                                    );
                                  },
                            child: const Text('Use Default'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: appCardDecoration(),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _AuthTextField(
                        controller: _nameController,
                        label: 'Product Name',
                        onChanged: (_) => setState(() {}),
                        validator: (String? value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Enter a product name.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _AuthTextField(
                        controller: _categoryController,
                        label: 'Category',
                        onChanged: (_) => setState(() {}),
                        validator: (String? value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Enter a category.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _AuthTextField(
                        controller: _descriptionController,
                        label: 'Description',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _AuthTextField(
                              controller: _priceController,
                              label: 'Price BHD',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (_) => setState(() {}),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]'),
                                ),
                              ],
                              validator: (String? value) {
                                final double? price = double.tryParse(
                                  (value ?? '').trim(),
                                );
                                if (price == null || price <= 0) {
                                  return 'Enter a valid price.';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _AuthTextField(
                              controller: _stockController,
                              label: 'Stock Qty',
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(5),
                              ],
                              validator: (String? value) {
                                final int? stock = int.tryParse(
                                  (value ?? '').trim(),
                                );
                                if (stock == null || stock < 0) {
                                  return 'Enter a valid stock value.';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: appCardDecoration(
                          color: AppPalette.background,
                          radius: 22,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'Preview',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: <Widget>[
                                _CatalogMetaChip(
                                  icon: Icons.label_outline_rounded,
                                  label: _nameController.text.trim().isEmpty
                                      ? 'Set a name'
                                      : _nameController.text.trim(),
                                ),
                                _CatalogMetaChip(
                                  icon: Icons.category_outlined,
                                  label: _categoryController.text.trim().isEmpty
                                      ? 'Set category'
                                      : _categoryController.text.trim(),
                                ),
                                _CatalogMetaChip(
                                  icon: Icons.payments_outlined,
                                  label: _priceController.text.trim().isEmpty
                                      ? 'Set price'
                                      : 'BHD ${_priceController.text.trim()}',
                                  emphasized: _priceController.text
                                      .trim()
                                      .isNotEmpty,
                                ),
                                _CatalogMetaChip(
                                  icon: Icons.inventory_2_outlined,
                                  label: _stockController.text.trim().isEmpty
                                      ? 'Set stock'
                                      : '${_stockController.text.trim()} units',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      SwitchListTile.adaptive(
                        value: _isActive,
                        onChanged: (bool value) {
                          setState(() => _isActive = value);
                        },
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active'),
                        subtitle: const Text(
                          'Active products appear in the salon retail catalog.',
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _save,
                          child: Text(widget.submitLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

int? _durationMinutesFromLabel(String? rawValue) {
  final String value = (rawValue ?? '').trim().toLowerCase();
  if (value.isEmpty) {
    return null;
  }
  final RegExpMatch? match = RegExp(r'(\d+)').firstMatch(value);
  return match == null ? null : int.tryParse(match.group(1)!);
}

class SalonOwnerSettingsScreen extends StatelessWidget {
  const SalonOwnerSettingsScreen({
    super.key,
    required this.user,
    required this.workspace,
    required this.platformRepository,
    required this.onUserChanged,
    required this.onOpenNotifications,
    required this.onOpenCatalogDetails,
    required this.onOpenSubscriptionDetails,
    required this.onOpenProfitDetails,
    required this.onLogout,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.isHighContrast,
    required this.onHighContrastChanged,
    required this.textScaleFactor,
    required this.onTextScaleChanged,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    required this.isBiometricLockEnabled,
    required this.onBiometricLockChanged,
  });

  final AppUser user;
  final SalonWorkspaceSnapshot? workspace;
  final PlatformRepository platformRepository;
  final ValueChanged<AppUser> onUserChanged;
  final Future<void> Function() onOpenNotifications;
  final Future<void> Function() onOpenCatalogDetails;
  final Future<void> Function() onOpenSubscriptionDetails;
  final Future<void> Function() onOpenProfitDetails;
  final VoidCallback onLogout;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final bool isHighContrast;
  final ValueChanged<bool> onHighContrastChanged;
  final double textScaleFactor;
  final ValueChanged<double> onTextScaleChanged;
  final String selectedLanguage;
  final ValueChanged<String> onLanguageChanged;
  final bool isBiometricLockEnabled;
  final AsyncBoolCallback onBiometricLockChanged;

  @override
  Widget build(BuildContext context) {
    final SalonSubscriptionStatus? subscriptionStatus =
        workspace?.subscriptionStatus;
    final String subscriptionSubtitle = subscriptionStatus == null
        ? 'Monthly ${formatBhd(salonMonthlySubscriptionPrice)} · Yearly ${formatBhd(salonYearlySubscriptionPrice)}'
        : subscriptionStatus.expiresAt == null
        ? '${subscriptionStatus.cycle.localizedLabel(context)} ${formatBhd(subscriptionStatus.amount)} · ${_tr(context, 'expiry not set yet', 'لم يتم تحديد الانتهاء بعد')}'
        : '${subscriptionStatus.cycle.localizedLabel(context)} ${formatBhd(subscriptionStatus.amount)} · ${_tr(context, 'expires', 'ينتهي')} ${formatCalendarDate(subscriptionStatus.expiresAt!)}';
    final String catalogSubtitle = workspace == null
        ? 'Open catalog tools after the approved salon workspace loads'
        : '${workspace!.packages.length} packages · ${workspace!.services.length} services · ${workspace!.products.length} products';
    final double operatingProfit = workspace == null
        ? 0
        : workspace!.finance.totalRevenue -
              workspace!.finance.salaryCost -
              workspace!.finance.subscriptionCost;
    final String profitSubtitle = workspace == null
        ? 'Revenue, salary cost, and profit analytics'
        : 'Revenue ${formatBhd(workspace!.finance.totalRevenue)} · Profit ${formatBhd(operatingProfit)}';
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: <Widget>[
          Text(
            _tr(context, 'Owner Settings', 'إعدادات المالك'),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: appCardDecoration(),
            child: Row(
              children: <Widget>[
                _ManagementAvatar(
                  imagePath: user.avatarPath,
                  radius: 30,
                  icon: Icons.storefront_rounded,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(color: AppPalette.mutedForeground),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${workspace == null ? 'Approved salon' : workspace!.salon.localizedName(context)} · ${user.phone}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppPalette.mutedForeground,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (workspace != null) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _MetricCard(
                      label: 'Profit',
                      value: formatBhd(operatingProfit),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      label: 'Team',
                      value: '${workspace!.employees.length}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      label: 'Bookings',
                      value:
                          '${workspace!.finance.upcomingBookings + workspace!.finance.completedBookings}',
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          _SettingsTile(
            item: _SettingsItem(
              icon: Icons.person_outline_rounded,
              label: 'Account Details',
              subtitle: 'Update your profile photo, phone, city, and password',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => AccountDetailsScreen(
                      user: user,
                      platformRepository: platformRepository,
                      onUserChanged: onUserChanged,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            item: _SettingsItem(
              icon: Icons.notifications_none_rounded,
              label: _tr(context, 'Notifications', 'الإشعارات'),
              subtitle: _tr(
                context,
                'Open your latest booking and product updates',
                'افتح آخر تحديثات حجوزاتك وطلبات المنتجات.',
              ),
              onTap: () => unawaited(onOpenNotifications()),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            item: _SettingsItem(
              icon: Icons.spa_outlined,
              label: 'Catalog',
              subtitle: catalogSubtitle,
              onTap: () => unawaited(onOpenCatalogDetails()),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            item: _SettingsItem(
              icon: Icons.workspace_premium_outlined,
              label: 'Subscription',
              subtitle: subscriptionSubtitle,
              onTap: () => unawaited(onOpenSubscriptionDetails()),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            item: _SettingsItem(
              icon: Icons.insights_outlined,
              label: 'Revenue & Profit',
              subtitle: profitSubtitle,
              onTap: () => unawaited(onOpenProfitDetails()),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            item: _SettingsItem(
              icon: Icons.palette_outlined,
              label: _tr(context, 'Appearance & Language', 'المظهر واللغة'),
              subtitle: _tr(
                context,
                'Adjust theme and language for the salon workspace',
                'عدّل الثيم واللغة لمساحة الصالون',
              ),
              onTap: () {
                showAppearanceSettingsSheet(
                  context: context,
                  isDarkMode: isDarkMode,
                  onThemeChanged: onThemeChanged,
                  isHighContrast: isHighContrast,
                  onHighContrastChanged: onHighContrastChanged,
                  textScaleFactor: textScaleFactor,
                  onTextScaleChanged: onTextScaleChanged,
                  selectedLanguage: selectedLanguage,
                  onLanguageChanged: onLanguageChanged,
                  subtitle: _tr(
                    context,
                    'Control contrast, font size, theme, and language for the salon workspace.',
                    'تحكم في التباين وحجم الخط والثيم واللغة لمساحة الصالون.',
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            item: _SettingsItem(
              icon: Icons.support_agent_rounded,
              label: 'Help & Support',
              subtitle:
                  'Open owner support channels for subscriptions and salon issues',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) =>
                        const HelpSupportScreen(role: AppRole.salonOwner),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            item: _SettingsItem(
              icon: Icons.shield_outlined,
              label: 'Privacy & Security',
              subtitle:
                  'Open the same privacy and security guidance as customers',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) =>
                        const PrivacySecurityScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            item: _SettingsItem(
              icon: Icons.fingerprint_rounded,
              label: _tr(context, 'Biometric Lock', 'قفل البصمة'),
              subtitle: isBiometricLockEnabled
                  ? _tr(
                      context,
                      'Enabled on this device for your saved session',
                      'مفعل على هذا الجهاز لجلسة الدخول المحفوظة',
                    )
                  : _tr(
                      context,
                      'Use fingerprint or device biometrics before opening the app',
                      'استخدم البصمة أو التحقق الحيوي قبل فتح التطبيق',
                    ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => BiometricLockScreen(
                      isEnabled: isBiometricLockEnabled,
                      onChanged: onBiometricLockChanged,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            item: _SettingsItem(
              icon: Icons.logout_rounded,
              label: 'Log Out',
              subtitle: 'Return to sign in',
              danger: true,
              onTap: () {
                unawaited(_confirmLogoutRequested(context, onLogout));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SalonEmployeeDetailsScreen extends StatefulWidget {
  const SalonEmployeeDetailsScreen({
    super.key,
    required this.actor,
    required this.platformRepository,
    required this.employee,
  });

  final AppUser actor;
  final PlatformRepository platformRepository;
  final Employee employee;

  @override
  State<SalonEmployeeDetailsScreen> createState() =>
      _SalonEmployeeDetailsScreenState();
}

class _SalonEmployeeDetailsScreenState
    extends State<SalonEmployeeDetailsScreen> {
  bool _isSubmitting = false;

  Future<void> _editEmployee() async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => SalonEmployeeEditorScreen(
          actor: widget.actor,
          platformRepository: widget.platformRepository,
          employee: widget.employee,
        ),
      ),
    );
    if (changed == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _toggleEmployee() async {
    final bool shouldContinue = await _showActionConfirmationDialog(
      context: context,
      title: widget.employee.isActive ? 'Pause Employee' : 'Enable Employee',
      message: widget.employee.isActive
          ? 'The employee can no longer sign in while paused.'
          : 'The employee will be able to sign in again.',
      confirmLabel: widget.employee.isActive ? 'Pause' : 'Enable',
    );
    if (!shouldContinue) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.platformRepository.setSalonEmployeeActive(
        actor: widget.actor,
        employeeId: widget.employee.id,
        isActive: !widget.employee.isActive,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteEmployee() async {
    final bool shouldDelete = await _showActionConfirmationDialog(
      context: context,
      title: 'Delete Employee',
      message:
          'Delete ${widget.employee.name} from the salon team and remove the linked employee account?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!shouldDelete) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.platformRepository.deleteSalonEmployee(
        actor: widget.actor,
        employeeId: widget.employee.id,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _toggleSalaryReceived() async {
    final bool isReceived = widget.employee.isSalaryReceivedForMonth();
    final bool shouldContinue = await _showActionConfirmationDialog(
      context: context,
      title: isReceived
          ? 'Remove Salary Confirmation'
          : 'Confirm Employee Salary',
      message: isReceived
          ? 'This will remove the current month salary confirmation for this employee.'
          : 'This will confirm the current month salary for ${widget.employee.name} so it counts in salon profit.',
      confirmLabel: isReceived ? 'Remove Confirmation' : 'Confirm Salary',
    );
    if (!shouldContinue) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.platformRepository.setSalonEmployeeSalaryReceived(
        actor: widget.actor,
        employeeId: widget.employee.id,
        isReceived: !isReceived,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Employee employee = widget.employee;
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: const Text('Employee Details')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: appCardDecoration(),
              child: Column(
                children: <Widget>[
                  _ManagementAvatar(
                    imagePath: employee.imagePath,
                    radius: 38,
                    icon: Icons.badge_rounded,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    employee.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    employee.role,
                    style: TextStyle(color: AppPalette.mutedForeground),
                  ),
                  const SizedBox(height: 10),
                  _TagCard(
                    label: employee.isActive
                        ? 'Account active'
                        : 'Account paused',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                children: <Widget>[
                  _SummaryRow(label: 'Email', value: employee.email),
                  _SummaryRow(label: 'Phone', value: employee.phone),
                  _SummaryRow(
                    label: 'Monthly salary',
                    value: formatBhd(employee.monthlySalary),
                  ),
                  _SummaryRow(
                    label: 'Salary due date',
                    value: formatCalendarDate(employee.salaryDueDate),
                  ),
                  _SummaryRow(
                    label: 'Salary status',
                    value: employee.isSalaryReceivedForMonth()
                        ? 'Received'
                        : 'Pending',
                  ),
                  if (employee.salaryLastPaidAt != null)
                    _SummaryRow(
                      label: 'Last received',
                      value: _formatBookingDateTime(employee.salaryLastPaidAt!),
                    ),
                  _SummaryRow(
                    label: 'Rating',
                    value:
                        '${employee.rating.toStringAsFixed(1)} (${employee.reviewsCount})',
                  ),
                  _SummaryRow(
                    label: 'Home service',
                    value: employee.supportsHomeService ? 'Yes' : 'No',
                  ),
                  _SummaryRow(
                    label: 'In-shop',
                    value: employee.supportsInShop ? 'Yes' : 'No',
                  ),
                  _SummaryRow(
                    label: 'Employee login',
                    value: employee.canLogin ? 'Enabled' : 'Disabled',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isSubmitting ? null : _editEmployee,
              child: const Text('Edit Employee'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: _isSubmitting ? null : _toggleSalaryReceived,
              child: Text(
                employee.isSalaryReceivedForMonth()
                    ? 'Mark Salary Pending'
                    : 'Mark Salary Received',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isSubmitting ? null : _toggleEmployee,
              child: Text(
                employee.isActive ? 'Pause Account' : 'Enable Account',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isSubmitting ? null : _deleteEmployee,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
              ),
              child: const Text('Delete Employee'),
            ),
          ],
        ),
      ),
    );
  }
}

class SalonEmployeeEditorScreen extends StatefulWidget {
  const SalonEmployeeEditorScreen({
    super.key,
    required this.actor,
    required this.platformRepository,
    this.employee,
  });

  final AppUser actor;
  final PlatformRepository platformRepository;
  final Employee? employee;

  @override
  State<SalonEmployeeEditorScreen> createState() =>
      _SalonEmployeeEditorScreenState();
}

class _SalonEmployeeEditorScreenState extends State<SalonEmployeeEditorScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController(
    text: widget.employee?.name ?? '',
  );
  late final TextEditingController _roleController = TextEditingController(
    text: widget.employee?.role ?? 'Salon Employee',
  );
  late final TextEditingController _emailController = TextEditingController(
    text: widget.employee?.email ?? '',
  );
  late final TextEditingController _phoneController = TextEditingController(
    text:
        normalizeBahrainPhone(widget.employee?.phone, allowEmpty: true) ??
        (widget.employee?.phone ?? '').trim(),
  );
  late final TextEditingController _salaryController = TextEditingController(
    text: widget.employee == null
        ? '250'
        : formatPrice(widget.employee!.monthlySalary),
  );
  final TextEditingController _passwordController = TextEditingController();
  late bool _supportsInShop = widget.employee?.supportsInShop ?? true;
  late bool _supportsHomeService =
      widget.employee?.supportsHomeService ?? false;
  late bool _canLogin = widget.employee?.canLogin ?? true;
  late TimeOfDay _workStartTime =
      _timeOfDayFromMinutes(widget.employee?.workStartMinutes) ??
      const TimeOfDay(hour: 9, minute: 0);
  late TimeOfDay _workEndTime =
      _timeOfDayFromMinutes(widget.employee?.workEndMinutes) ??
      const TimeOfDay(hour: 17, minute: 0);
  late bool _hasBreak = widget.employee?.breakStartMinutes != null &&
      widget.employee?.breakEndMinutes != null;
  late TimeOfDay _breakStartTime =
      _timeOfDayFromMinutes(widget.employee?.breakStartMinutes) ??
      const TimeOfDay(hour: 13, minute: 0);
  late TimeOfDay _breakEndTime =
      _timeOfDayFromMinutes(widget.employee?.breakEndMinutes) ??
      const TimeOfDay(hour: 14, minute: 0);
  late String _avatarPath = widget.employee?.imagePath.trim().isNotEmpty == true
      ? widget.employee!.imagePath
      : currentDefaultProfileImageUrl();
  bool _isSaving = false;
  bool _hidePassword = true;
  bool _isUploadingAvatar = false;
  late final String _draftProfileImageKey =
      widget.employee?.profileId ??
      'employee-${DateTime.now().millisecondsSinceEpoch}';

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _salaryController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  static TimeOfDay? _timeOfDayFromMinutes(int? minutes) {
    if (minutes == null || minutes < 0) {
      return null;
    }
    final int hour = minutes ~/ 60;
    final int minute = minutes % 60;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  static int _minutesOfDay(TimeOfDay time) => (time.hour * 60) + time.minute;

  static String _formatTimeOfDay(TimeOfDay time) {
    final String hh = time.hour.toString().padLeft(2, '0');
    final String mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm:00';
  }

  Future<void> _pickTime({
    required TimeOfDay initialTime,
    required ValueChanged<TimeOfDay> onPicked,
  }) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (!mounted || picked == null) {
      return;
    }
    onPicked(picked);
  }

  String get _profileImageKey {
    final String existingProfileId = (widget.employee?.profileId ?? '').trim();
    if (existingProfileId.isNotEmpty) {
      return existingProfileId;
    }
    final String email = _emailController.text.trim();
    if (email.isNotEmpty) {
      return email;
    }
    final String name = _nameController.text.trim();
    if (name.isNotEmpty) {
      return name;
    }
    return _draftProfileImageKey;
  }

  Future<void> _uploadAvatar() async {
    setState(() => _isUploadingAvatar = true);
    try {
      final String? uploadedPath = await widget.platformRepository
          .pickAndUploadProfileImage(profileKey: _profileImageKey);
      if (!mounted || uploadedPath == null || uploadedPath.trim().isEmpty) {
        return;
      }
      setState(() => _avatarPath = uploadedPath.trim());
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!_supportsInShop && !_supportsHomeService) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enable at least one service mode for this employee.'),
        ),
      );
      return;
    }

    final int workStart = _minutesOfDay(_workStartTime);
    final int workEnd = _minutesOfDay(_workEndTime);
    if (workEnd <= workStart) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Work end time must be after start time.')),
      );
      return;
    }
    if (_hasBreak) {
      final int breakStart = _minutesOfDay(_breakStartTime);
      final int breakEnd = _minutesOfDay(_breakEndTime);
      if (breakEnd <= breakStart) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Break end time must be after break start time.'),
          ),
        );
        return;
      }
      if (breakStart < workStart || breakEnd > workEnd) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Break must be within working hours.'),
          ),
        );
        return;
      }
    }

    final double? salary = double.tryParse(_salaryController.text.trim());
    if (salary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid monthly salary.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.platformRepository.saveSalonEmployee(
        actor: widget.actor,
        employeeId: widget.employee?.id,
        profileId: widget.employee?.profileId,
        name: _nameController.text.trim(),
        roleTitle: _roleController.text.trim(),
        email: _emailController.text.trim(),
        phone: normalizeBahrainPhoneOrThrow(_phoneController.text),
        monthlySalary: salary,
        supportsInShop: _supportsInShop,
        supportsHomeService: _supportsHomeService,
        canLogin: _canLogin,
        workStartTime: _formatTimeOfDay(_workStartTime),
        workEndTime: _formatTimeOfDay(_workEndTime),
        breakStartTime: _hasBreak ? _formatTimeOfDay(_breakStartTime) : null,
        breakEndTime: _hasBreak ? _formatTimeOfDay(_breakEndTime) : null,
        password: _passwordController.text.trim().isEmpty
            ? null
            : _passwordController.text.trim(),
        avatarPath: _avatarPath.trim().isEmpty
            ? currentDefaultProfileImageUrl()
            : _avatarPath.trim(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.employee == null ? 'Add Employee' : 'Edit Employee',
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: appCardDecoration(),
                child: Column(
                  children: <Widget>[
                    _ManagementAvatar(
                      imagePath: _avatarPath,
                      radius: 36,
                      icon: Icons.badge_rounded,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Employee profile image',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Optional. If you skip this, Freshline will use the default profile image.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppPalette.mutedForeground,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUploadingAvatar
                                ? null
                                : _uploadAvatar,
                            icon: _isUploadingAvatar
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.photo_camera_outlined),
                            label: Text(
                              isDefaultProfileImageSelection(_avatarPath)
                                  ? 'Upload Photo'
                                  : 'Replace Photo',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextButton(
                            onPressed: _isUploadingAvatar
                                ? null
                                : () {
                                    setState(
                                      () => _avatarPath =
                                          currentDefaultProfileImageUrl(),
                                    );
                                  },
                            child: const Text('Use Default'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Employee name'),
                validator: (String? value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Enter the employee name.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _roleController,
                decoration: const InputDecoration(labelText: 'Role title'),
                validator: (String? value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Enter the role title.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (String? value) {
                  final String normalized = (value ?? '').trim();
                  if (normalized.isEmpty || !normalized.contains('@')) {
                    return 'Enter a valid email.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: bahrainPhoneInputFormatters,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: validateRequiredBahrainPhone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _salaryController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monthly salary (BHD)',
                ),
                validator: (String? value) {
                  if (double.tryParse((value ?? '').trim()) == null) {
                    return 'Enter a valid salary.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _hidePassword,
                decoration: InputDecoration(
                  labelText: widget.employee == null
                      ? 'Password (optional)'
                      : 'New password (optional)',
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => _hidePassword = !_hidePassword);
                    },
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SwitchListTile.adaptive(
                value: _supportsInShop,
                onChanged: (bool value) {
                  setState(() => _supportsInShop = value);
                },
                title: const Text('Supports in-shop bookings'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile.adaptive(
                value: _supportsHomeService,
                onChanged: (bool value) {
                  setState(() => _supportsHomeService = value);
                },
                title: const Text('Supports home service'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: appCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Working hours',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Start'),
                      trailing: Text(_workStartTime.format(context)),
                      onTap: () => _pickTime(
                        initialTime: _workStartTime,
                        onPicked: (TimeOfDay time) =>
                            setState(() => _workStartTime = time),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('End'),
                      trailing: Text(_workEndTime.format(context)),
                      onTap: () => _pickTime(
                        initialTime: _workEndTime,
                        onPicked: (TimeOfDay time) =>
                            setState(() => _workEndTime = time),
                      ),
                    ),
                    const Divider(height: 18),
                    SwitchListTile.adaptive(
                      value: _hasBreak,
                      onChanged: (bool value) => setState(() => _hasBreak = value),
                      title: const Text('Add break time'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_hasBreak) ...<Widget>[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Break start'),
                        trailing: Text(_breakStartTime.format(context)),
                        onTap: () => _pickTime(
                          initialTime: _breakStartTime,
                          onPicked: (TimeOfDay time) =>
                              setState(() => _breakStartTime = time),
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Break end'),
                        trailing: Text(_breakEndTime.format(context)),
                        onTap: () => _pickTime(
                          initialTime: _breakEndTime,
                          onPicked: (TimeOfDay time) =>
                              setState(() => _breakEndTime = time),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SwitchListTile.adaptive(
                value: _canLogin,
                onChanged: (bool value) {
                  setState(() => _canLogin = value);
                },
                title: const Text('Can sign in as employee'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: appCardDecoration(
                  color: AppPalette.secondary,
                  radius: 20,
                ),
                child: Text(
                  _passwordController.text.trim().isEmpty
                      ? 'If you leave the password empty, Freshline will keep the existing password or use the default employee password.'
                      : 'The entered password will be saved for the employee account.',
                  style: TextStyle(color: AppPalette.mutedForeground),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: Text(
                  _isSaving
                      ? 'Saving...'
                      : widget.employee == null
                      ? 'Add Employee'
                      : 'Save Changes',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmployeeShell extends StatefulWidget {
  const EmployeeShell({
    super.key,
    required this.user,
    required this.onLogout,
    required this.platformRepository,
    required this.notificationsService,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.isHighContrast,
    required this.onHighContrastChanged,
    required this.textScaleFactor,
    required this.onTextScaleChanged,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    required this.onUserChanged,
    required this.isBiometricLockEnabled,
    required this.onBiometricLockChanged,
  });

  final AppUser user;
  final VoidCallback onLogout;
  final PlatformRepository platformRepository;
  final NotificationsService notificationsService;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final bool isHighContrast;
  final ValueChanged<bool> onHighContrastChanged;
  final double textScaleFactor;
  final ValueChanged<double> onTextScaleChanged;
  final String selectedLanguage;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<AppUser> onUserChanged;
  final bool isBiometricLockEnabled;
  final AsyncBoolCallback onBiometricLockChanged;

  @override
  State<EmployeeShell> createState() => _EmployeeShellState();
}

class _EmployeeShellState extends State<EmployeeShell> {
  int _currentIndex = 0;
  late AppUser _user = widget.user;
  SalonWorkspaceSnapshot? _workspace;
  bool _isLoadingWorkspace = true;
  List<AppNotificationItem> _notifications = <AppNotificationItem>[];
  bool _isNotificationsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
    _loadNotifications(showLoading: false);
  }

  @override
  void didUpdateWidget(covariant EmployeeShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedLanguage != oldWidget.selectedLanguage ||
        widget.user.preferredLanguage != oldWidget.user.preferredLanguage ||
        widget.user.profileId != oldWidget.user.profileId) {
      unawaited(_loadWorkspace());
      unawaited(_loadNotifications(showLoading: false));
    }
  }

  Future<void> _loadWorkspace() async {
    setState(() => _isLoadingWorkspace = true);
    try {
      final SalonWorkspaceSnapshot workspace = await widget.platformRepository
          .loadSalonWorkspace(user: _user);
      if (!mounted) {
        return;
      }
      setState(() => _workspace = workspace);
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingWorkspace = false);
      }
    }
  }

  Future<void> _loadNotifications({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() => _isNotificationsLoading = true);
    }

    try {
      final List<AppNotificationItem> notifications = await widget
          .notificationsService
          .loadNotifications(user: _user);
      if (!mounted) {
        return;
      }
      setState(() => _notifications = notifications);
    } catch (_) {
      if (!mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() => _isNotificationsLoading = false);
      }
    }
  }

  Future<void> _openNotifications() async {
    await _loadNotifications();
    if (!mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => NotificationsScreen(
          notifications: _notifications,
          isLoading: _isNotificationsLoading,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _notifications = _notifications
          .map(
            (AppNotificationItem item) =>
                item.unread ? item.copyWith(unread: false) : item,
          )
          .toList(growable: false);
    });
  }

  bool get _hasUnreadNotifications =>
      _notifications.any((AppNotificationItem item) => item.unread);

  @override
  Widget build(BuildContext context) {
    final List<_NavItem> tabs = <_NavItem>[
      _NavItem(
        Icons.dashboard_customize_rounded,
        _tr(context, 'Dashboard', 'لوحة التحكم'),
      ),
      _NavItem(
        Icons.calendar_month_rounded,
        _tr(context, 'Bookings', 'الحجوزات'),
      ),
      _NavItem(Icons.auto_awesome_rounded, _tr(context, 'AI', 'الذكاء')),
      _NavItem(Icons.settings_rounded, _tr(context, 'Settings', 'الإعدادات')),
    ];
    final List<Widget> pages = <Widget>[
      EmployeeDashboardScreen(
        user: _user,
        workspace: _workspace,
        isLoading: _isLoadingWorkspace,
        onRefresh: _loadWorkspace,
        onOpenNotifications: _openNotifications,
        hasUnreadNotifications: _hasUnreadNotifications,
      ),
      EmployeeBookingsScreen(
        user: _user,
        platformRepository: widget.platformRepository,
        workspace: _workspace,
        isLoading: _isLoadingWorkspace,
        onRefresh: _loadWorkspace,
      ),
      AiStylistScreen(
        role: AppRole.employee,
        selectedLanguage: widget.selectedLanguage,
      ),
      EmployeeSettingsScreen(
        user: _user,
        platformRepository: widget.platformRepository,
        onOpenNotifications: _openNotifications,
        onUserChanged: (AppUser updatedUser) {
          setState(() => _user = updatedUser);
          widget.onUserChanged(updatedUser);
          unawaited(_loadWorkspace());
          unawaited(_loadNotifications(showLoading: false));
        },
        onLogout: widget.onLogout,
        isDarkMode: widget.isDarkMode,
        onThemeChanged: widget.onThemeChanged,
        isHighContrast: widget.isHighContrast,
        onHighContrastChanged: widget.onHighContrastChanged,
        textScaleFactor: widget.textScaleFactor,
        onTextScaleChanged: widget.onTextScaleChanged,
        selectedLanguage: widget.selectedLanguage,
        onLanguageChanged: widget.onLanguageChanged,
        isBiometricLockEnabled: widget.isBiometricLockEnabled,
        onBiometricLockChanged: widget.onBiometricLockChanged,
      ),
    ];

    return AppViewport(
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: pages),
        bottomNavigationBar: _ManagementNavigationBar(
          tabs: tabs,
          currentIndex: _currentIndex,
          onSelect: (int index) => setState(() => _currentIndex = index),
        ),
      ),
    );
  }
}

class EmployeeDashboardScreen extends StatelessWidget {
  const EmployeeDashboardScreen({
    super.key,
    required this.user,
    required this.workspace,
    required this.isLoading,
    required this.onRefresh,
    required this.onOpenNotifications,
    required this.hasUnreadNotifications,
  });

  final AppUser user;
  final SalonWorkspaceSnapshot? workspace;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onOpenNotifications;
  final bool hasUnreadNotifications;

  @override
  Widget build(BuildContext context) {
    final Employee? employee = workspace?.currentEmployee;
    final List<UserOrder> bookings = workspace?.bookings ?? const <UserOrder>[];
    final int completed = bookings
        .where((UserOrder order) => _isManagementOrderCompleted(order))
        .length;
    final int upcoming = bookings.length - completed;
    final bool salaryReceived = employee?.isSalaryReceivedForMonth() ?? false;

    return SafeArea(
      bottom: false,
      child: isLoading && workspace == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: appCardDecoration(),
                  child: Row(
                    children: <Widget>[
                      _ManagementAvatar(
                        imagePath: employee?.imagePath ?? user.avatarPath,
                        radius: 34,
                        icon: Icons.badge_rounded,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              user.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              employee?.role ?? 'Salon Employee',
                              style: TextStyle(
                                color: AppPalette.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              workspace?.salon.localizedName(context) ??
                                  'FreshLine Salon',
                              style: TextStyle(
                                color: AppPalette.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ManagementNotificationsButton(
                        hasUnread: hasUnreadNotifications,
                        onTap: () => unawaited(onOpenNotifications()),
                      ),
                      IconButton(
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: appCardDecoration(),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _MetricCard(
                          label: 'Upcoming',
                          value: '$upcoming',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          label: 'Completed',
                          value: '$completed',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          label: 'Rating',
                          value: employee == null
                              ? '-'
                              : employee.rating.toStringAsFixed(1),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (employee != null)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: appCardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Salary Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _AccountInfoRow(
                          label: 'Due date',
                          value: formatCalendarDate(employee.salaryDueDate),
                        ),
                        const SizedBox(height: 8),
                        _AccountInfoRow(
                          label: 'This month',
                          value: salaryReceived ? 'Confirmed' : 'Pending',
                        ),
                        if (employee.salaryLastPaidAt != null) ...<Widget>[
                          const SizedBox(height: 8),
                          _AccountInfoRow(
                            label: 'Last confirmed',
                            value: _formatBookingDateTime(
                              employee.salaryLastPaidAt!,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (employee != null) const SizedBox(height: 16),
                if (bookings.isEmpty)
                  _EmptyStateCard(
                    icon: Icons.event_busy_rounded,
                    title: 'No assigned bookings',
                    message:
                        'Your confirmed customer appointments will appear here.',
                    actionLabel: 'Refresh',
                    onAction: () => unawaited(onRefresh()),
                  )
                else
                  ...bookings.take(6).map((UserOrder order) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: appCardDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              order.serviceName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              order.customerName ?? 'Freshline Customer',
                              style: TextStyle(
                                color: AppPalette.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if ((order.customerPhone ?? '')
                                .trim()
                                .isNotEmpty) ...<Widget>[
                              const SizedBox(height: 8),
                              _AccountInfoRow(
                                label: 'Phone',
                                value: order.customerPhone!,
                              ),
                            ],
                            const SizedBox(height: 8),
                            _AccountInfoRow(
                              label: 'Time',
                              value: _formatBookingDateTime(order.scheduledAt),
                            ),
                            const SizedBox(height: 8),
                            _AccountInfoRow(
                              label: 'Visit',
                              value: order.visitMode,
                            ),
                            if ((order.address ?? '')
                                .trim()
                                .isNotEmpty) ...<Widget>[
                              const SizedBox(height: 8),
                              _AccountInfoRow(
                                label: 'Address',
                                value: order.address!,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}

class EmployeeBookingsScreen extends StatelessWidget {
  const EmployeeBookingsScreen({
    super.key,
    required this.user,
    required this.platformRepository,
    required this.workspace,
    required this.isLoading,
    required this.onRefresh,
  });

  final AppUser user;
  final PlatformRepository platformRepository;
  final SalonWorkspaceSnapshot? workspace;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  Widget _buildProductOrderCard(
    UserOrder order, {
    required VoidCallback onTap,
  }) {
    final bool completed = _isManagementOrderCompleted(order);
    final bool isAvailable = order.isUnassignedProductOrder;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: appCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      order.serviceName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: completed
                          ? AppPalette.secondary
                          : isAvailable
                          ? const Color(0xFFD97706).withValues(alpha: 0.14)
                          : AppPalette.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isAvailable && !completed
                          ? 'Available'
                          : order.statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: completed
                            ? AppPalette.foreground
                            : isAvailable
                            ? const Color(0xFFD97706)
                            : AppPalette.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _AccountInfoRow(
                label: 'Invoice',
                value: order.displayInvoiceNumber,
              ),
              const SizedBox(height: 8),
              _AccountInfoRow(
                label: 'Customer',
                value: order.customerName ?? 'Freshline Customer',
              ),
              if ((order.customerPhone ?? '').trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                _AccountInfoRow(label: 'Phone', value: order.customerPhone!),
              ],
              const SizedBox(height: 8),
              _AccountInfoRow(
                label: 'Ordered at',
                value: _formatBookingDateTime(order.scheduledAt),
              ),
              const SizedBox(height: 8),
              _AccountInfoRow(label: 'Assigned', value: order.employeeName),
              if ((order.address ?? '').trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                _AccountInfoRow(label: 'Address', value: order.address!),
              ],
              const SizedBox(height: 8),
              _AccountInfoRow(label: 'Total', value: formatBhd(order.total)),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  isAvailable && !completed ? 'Take order' : 'Open details',
                  style: TextStyle(
                    color: AppPalette.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingCard(UserOrder order, {required VoidCallback onTap}) {
    final bool completed = _isManagementOrderCompleted(order);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: appCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      order.serviceName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: completed
                          ? AppPalette.secondary
                          : AppPalette.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      order.statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: completed
                            ? AppPalette.foreground
                            : AppPalette.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _AccountInfoRow(
                label: 'Invoice',
                value: order.displayInvoiceNumber,
              ),
              const SizedBox(height: 8),
              _AccountInfoRow(
                label: 'Customer',
                value: order.customerName ?? 'Freshline Customer',
              ),
              if ((order.customerPhone ?? '').trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                _AccountInfoRow(label: 'Phone', value: order.customerPhone!),
              ],
              const SizedBox(height: 8),
              _AccountInfoRow(
                label: 'Time',
                value: _formatBookingDateTime(order.scheduledAt),
              ),
              const SizedBox(height: 8),
              _AccountInfoRow(label: 'Visit mode', value: order.visitMode),
              if ((order.address ?? '').trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                _AccountInfoRow(label: 'Address', value: order.address!),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Open details',
                  style: TextStyle(
                    color: AppPalette.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<UserOrder> bookings = workspace?.bookings ?? const <UserOrder>[];
    final List<UserOrder> productOrders =
        workspace?.productOrders ?? const <UserOrder>[];
    final List<UserOrder> activeBookings = bookings
        .where((UserOrder order) => !_isManagementOrderCompleted(order))
        .toList(growable: false);
    final List<UserOrder> completedBookings = bookings
        .where(_isManagementOrderCompleted)
        .toList(growable: false);
    final List<UserOrder> activeProductOrders = productOrders
        .where((UserOrder order) => !_isManagementOrderCompleted(order))
        .toList(growable: false);
    final List<UserOrder> completedProductOrders = productOrders
        .where(_isManagementOrderCompleted)
        .toList(growable: false);
    Future<void> openProductOrder(UserOrder order) async {
      final bool? changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (BuildContext context) =>
              ManagementProductOrderDetailsScreen(
                actor: user,
                platformRepository: platformRepository,
                order: order,
              ),
        ),
      );
      if (changed == true) {
        await onRefresh();
      }
    }

    Future<void> openBooking(UserOrder order) async {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              ManagementSalonBookingDetailsScreen(order: order),
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: isLoading && workspace == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        'My Orders & Bookings',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => unawaited(onRefresh()),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (productOrders.isEmpty)
                  _EmptyStateCard(
                    icon: Icons.inventory_2_outlined,
                    title: 'No product orders yet',
                    message:
                        'Available product orders will appear here until one employee takes them.',
                  )
                else ...<Widget>[
                  const Text(
                    'Product Orders',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  const _SectionLabel(
                    title: 'Open & In Progress',
                    subtitle:
                        'Available orders and the ones you already accepted stay here.',
                  ),
                  const SizedBox(height: 12),
                  if (activeProductOrders.isEmpty)
                    _EmptyStateCard(
                      icon: Icons.inventory_outlined,
                      title: 'No open product orders',
                      message:
                          'Accepted and available product orders will show here.',
                    )
                  else
                    ...activeProductOrders.map(
                      (UserOrder order) => _buildProductOrderCard(
                        order,
                        onTap: () => unawaited(openProductOrder(order)),
                      ),
                    ),
                  const SizedBox(height: 8),
                  const _SectionLabel(
                    title: 'Completed Product Orders',
                    subtitle:
                        'Delivered product orders stay here for reference.',
                  ),
                  const SizedBox(height: 12),
                  if (completedProductOrders.isEmpty)
                    _EmptyStateCard(
                      icon: Icons.inventory_2_outlined,
                      title: 'No completed product orders',
                      message:
                          'Delivered product orders will move here automatically.',
                    )
                  else
                    ...completedProductOrders.map(
                      (UserOrder order) => _buildProductOrderCard(
                        order,
                        onTap: () => unawaited(openProductOrder(order)),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
                if (bookings.isEmpty)
                  _EmptyStateCard(
                    icon: Icons.event_busy_rounded,
                    title: 'No bookings yet',
                    message:
                        'Customer appointments assigned to you will appear here.',
                  )
                else ...<Widget>[
                  const Text(
                    'Service Bookings',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  const _SectionLabel(
                    title: 'Coming & In Progress',
                    subtitle:
                        'Upcoming appointments and active services stay in this list.',
                  ),
                  const SizedBox(height: 12),
                  if (activeBookings.isEmpty)
                    _EmptyStateCard(
                      icon: Icons.upcoming_outlined,
                      title: 'No coming appointments',
                      message:
                          'Upcoming and in-progress appointments will show here.',
                    )
                  else
                    ...activeBookings.map(
                      (UserOrder order) => _buildBookingCard(
                        order,
                        onTap: () => unawaited(openBooking(order)),
                      ),
                    ),
                  const SizedBox(height: 8),
                  const _SectionLabel(
                    title: 'Completed Appointments',
                    subtitle:
                        'Finished appointments stay here as a separate history list.',
                  ),
                  const SizedBox(height: 12),
                  if (completedBookings.isEmpty)
                    _EmptyStateCard(
                      icon: Icons.task_alt_rounded,
                      title: 'No completed appointments',
                      message:
                          'Completed appointments will move here automatically.',
                    )
                  else
                    ...completedBookings.map(
                      (UserOrder order) => _buildBookingCard(
                        order,
                        onTap: () => unawaited(openBooking(order)),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

class EmployeeSettingsScreen extends StatelessWidget {
  const EmployeeSettingsScreen({
    super.key,
    required this.user,
    required this.platformRepository,
    required this.onOpenNotifications,
    required this.onUserChanged,
    required this.onLogout,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.isHighContrast,
    required this.onHighContrastChanged,
    required this.textScaleFactor,
    required this.onTextScaleChanged,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    required this.isBiometricLockEnabled,
    required this.onBiometricLockChanged,
  });

  final AppUser user;
  final PlatformRepository platformRepository;
  final Future<void> Function() onOpenNotifications;
  final ValueChanged<AppUser> onUserChanged;
  final VoidCallback onLogout;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final bool isHighContrast;
  final ValueChanged<bool> onHighContrastChanged;
  final double textScaleFactor;
  final ValueChanged<double> onTextScaleChanged;
  final String selectedLanguage;
  final ValueChanged<String> onLanguageChanged;
  final bool isBiometricLockEnabled;
  final AsyncBoolCallback onBiometricLockChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: <Widget>[
          Text(
            _tr(context, 'Employee Settings', 'إعدادات الموظف'),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: appCardDecoration(),
            child: Row(
              children: <Widget>[
                _ManagementAvatar(
                  imagePath: user.avatarPath,
                  radius: 28,
                  icon: Icons.badge_rounded,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(color: AppPalette.mutedForeground),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsTile(
            item: _SettingsItem(
              icon: Icons.person_outline_rounded,
              label: 'Account Details',
              subtitle: 'Update your profile photo, phone, city, and password.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => AccountDetailsScreen(
                      user: user,
                      platformRepository: platformRepository,
                      onUserChanged: onUserChanged,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            item: _SettingsItem(
              icon: Icons.notifications_none_rounded,
              label: _tr(context, 'Notifications', 'الإشعارات'),
              subtitle: _tr(
                context,
                'Open your latest appointment and product updates.',
                'افتح آخر تحديثات المواعيد والمنتجات.',
              ),
              onTap: () => unawaited(onOpenNotifications()),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            item: _SettingsItem(
              icon: Icons.palette_outlined,
              label: _tr(context, 'Appearance & Language', 'المظهر واللغة'),
              subtitle: _tr(
                context,
                'Adjust theme and language for your employee app view.',
                'عدّل الثيم واللغة لواجهة الموظف.',
              ),
              onTap: () {
                showAppearanceSettingsSheet(
                  context: context,
                  isDarkMode: isDarkMode,
                  onThemeChanged: onThemeChanged,
                  isHighContrast: isHighContrast,
                  onHighContrastChanged: onHighContrastChanged,
                  textScaleFactor: textScaleFactor,
                  onTextScaleChanged: onTextScaleChanged,
                  selectedLanguage: selectedLanguage,
                  onLanguageChanged: onLanguageChanged,
                  subtitle: _tr(
                    context,
                    'Control contrast, font size, theme, and language for the employee app.',
                    'تحكم في التباين وحجم الخط والثيم واللغة لتطبيق الموظف.',
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            item: _SettingsItem(
              icon: Icons.fingerprint_rounded,
              label: _tr(context, 'Biometric Lock', 'قفل البصمة'),
              subtitle: isBiometricLockEnabled
                  ? _tr(
                      context,
                      'Enabled on this device for your saved session',
                      'مفعل على هذا الجهاز لجلسة الدخول المحفوظة',
                    )
                  : _tr(
                      context,
                      'Use fingerprint or device biometrics before opening the app',
                      'استخدم البصمة أو التحقق الحيوي قبل فتح التطبيق',
                    ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => BiometricLockScreen(
                      isEnabled: isBiometricLockEnabled,
                      onChanged: onBiometricLockChanged,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            item: _SettingsItem(
              icon: Icons.support_agent_rounded,
              label: 'Contact Support',
              subtitle: 'Open support channels when you need help.',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) =>
                        const HelpSupportScreen(role: AppRole.employee),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            item: _SettingsItem(
              icon: Icons.logout_rounded,
              label: 'Log Out',
              subtitle: 'Sign out of the employee account.',
              danger: true,
              onTap: () {
                unawaited(_confirmLogoutRequested(context, onLogout));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AdminShell extends StatefulWidget {
  const AdminShell({
    super.key,
    required this.user,
    required this.onLogout,
    required this.platformRepository,
    required this.onUserChanged,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.isHighContrast,
    required this.onHighContrastChanged,
    required this.textScaleFactor,
    required this.onTextScaleChanged,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    required this.isBiometricLockEnabled,
    required this.onBiometricLockChanged,
  });

  final AppUser user;
  final VoidCallback onLogout;
  final PlatformRepository platformRepository;
  final ValueChanged<AppUser> onUserChanged;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final bool isHighContrast;
  final ValueChanged<bool> onHighContrastChanged;
  final double textScaleFactor;
  final ValueChanged<double> onTextScaleChanged;
  final String selectedLanguage;
  final ValueChanged<String> onLanguageChanged;
  final bool isBiometricLockEnabled;
  final AsyncBoolCallback onBiometricLockChanged;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;
  final Set<int> _loadedPageIndexes = <int>{0};
  List<AdminTeamMember> _admins = <AdminTeamMember>[];
  List<ManagedUserRecord> _users = <ManagedUserRecord>[];
  List<Salon> _salons = <Salon>[];
  List<AdminSalonRecord> _adminSalons = <AdminSalonRecord>[];
  List<AdminSalonRequestRecord> _requests = <AdminSalonRequestRecord>[];
  List<PromoCouponRecord> _coupons = <PromoCouponRecord>[];
  List<AdminCustomerSubscriptionRecord> _customerSubscriptions =
      <AdminCustomerSubscriptionRecord>[];
  List<Product> _adminProducts = <Product>[];
  List<AdminActivityLogRecord> _activityLogs = <AdminActivityLogRecord>[];
  AdminDashboardMetrics _metrics = const AdminDashboardMetrics(
    customerSubscriptionRevenue: 0,
    salonSubscriptionRevenue: 0,
    bookingRevenue: 0,
    productRevenue: 0,
    totalRevenue: 0,
    customerCount: 0,
    salonCount: 0,
    requestCount: 0,
    customerSubscriptionCount: 0,
    salonSubscriptionCount: 0,
    productCount: 0,
    productOrderCount: 0,
  );
  bool _isLoadingSnapshot = true;

  void _applySnapshot(AdminSnapshot snapshot) {
    _admins = snapshot.admins;
    _users = snapshot.users;
    _salons = snapshot.salons;
    _adminSalons = snapshot.adminSalons;
    _requests = snapshot.requests;
    _coupons = List<PromoCouponRecord>.from(snapshot.coupons, growable: false);
    _customerSubscriptions = snapshot.customerSubscriptions;
    _adminProducts = snapshot.adminProducts;
    _activityLogs = snapshot.activityLogs;
    _metrics = snapshot.metrics;
  }

  @override
  void initState() {
    super.initState();
    _refreshSnapshot(showLoading: true);
  }

  @override
  void didUpdateWidget(covariant AdminShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedLanguage != oldWidget.selectedLanguage ||
        widget.user.preferredLanguage != oldWidget.user.preferredLanguage ||
        widget.user.profileId != oldWidget.user.profileId) {
      unawaited(_refreshSnapshot());
    }
  }

  Future<void> _refreshSnapshot({bool showLoading = false}) async {
    if (showLoading && mounted) {
      setState(() => _isLoadingSnapshot = true);
    }

    try {
      final AdminSnapshot snapshot = await widget.platformRepository
          .loadAdminSnapshot();
      if (!mounted) {
        return;
      }
      setState(() {
        _applySnapshot(snapshot);
        _isLoadingSnapshot = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingSnapshot = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  Future<void> _toggleAdmin(AdminTeamMember admin) async {
    if (!widget.user.isAdminOwner) {
      return;
    }
    try {
      await widget.platformRepository.setAdminAccountActive(
        actor: widget.user,
        adminId: admin.id,
        isActive: !admin.isActive,
      );
      if (!mounted) {
        return;
      }
      await _refreshSnapshot();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            admin.isActive
                ? '${admin.name} was disabled.'
                : '${admin.name} was enabled.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  Future<void> _openAdminEditor(AdminTeamMember? admin) async {
    if (!widget.user.isAdminOwner) {
      return;
    }
    final bool? didSave = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => AdminEditorScreen(
          actor: widget.user,
          platformRepository: widget.platformRepository,
          existing: admin,
        ),
      ),
    );

    if (didSave != true || !mounted) {
      return;
    }
    await _refreshSnapshot();
  }

  Future<void> _openUsersScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AdminUsersScreen(
          adminUser: widget.user,
          users: _users,
          loadUsers: () async {
            final AdminSnapshot snapshot = await widget.platformRepository
                .loadAdminSnapshot();
            if (mounted) {
              setState(() {
                _applySnapshot(snapshot);
              });
            }
            return snapshot.users;
          },
          onSaveUser:
              ({
                required ManagedUserRecord user,
                required String name,
                required String email,
                required String phone,
                required String city,
                required AppRole role,
              }) async {
                await widget.platformRepository.updateManagedUser(
                  actor: widget.user,
                  user: user,
                  name: name,
                  email: email,
                  phone: phone,
                  city: city,
                  role: role,
                );
                await _refreshSnapshot();
              },
          onToggleUser:
              ({required String userId, required bool isActive}) async {
                await widget.platformRepository.setUserActive(
                  actor: widget.user,
                  userId: userId,
                  isActive: isActive,
                );
                await _refreshSnapshot();
              },
        ),
      ),
    );
  }

  Future<List<AdminTeamMember>> _loadAdmins() async {
    final AdminSnapshot snapshot = await widget.platformRepository
        .loadAdminSnapshot();
    if (mounted) {
      setState(() {
        _applySnapshot(snapshot);
      });
    }
    return snapshot.admins;
  }

  Future<void> _openAdminsScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AdminTeamScreen(
          adminUser: widget.user,
          admins: _admins,
          loadAdmins: _loadAdmins,
          onEditAdmin: _openAdminEditor,
          onToggleAdmin: _toggleAdmin,
        ),
      ),
    );
  }

  Future<List<AdminSalonRecord>> _loadAdminSalons() async {
    final AdminSnapshot snapshot = await widget.platformRepository
        .loadAdminSnapshot();
    if (mounted) {
      setState(() => _applySnapshot(snapshot));
    }
    return snapshot.adminSalons;
  }

  Future<void> _openSalonsScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AdminSalonsScreen(
          salons: _adminSalons,
          isLoading: _isLoadingSnapshot,
          loadSalons: _loadAdminSalons,
        ),
      ),
    );
  }

  Future<List<AdminCustomerSubscriptionRecord>>
  _loadCustomerSubscriptions() async {
    final AdminSnapshot snapshot = await widget.platformRepository
        .loadAdminSnapshot();
    if (mounted) {
      setState(() => _applySnapshot(snapshot));
    }
    return snapshot.customerSubscriptions;
  }

  Future<void> _openCustomerSubscriptionsScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AdminCustomerSubscriptionsScreen(
          subscriptions: _customerSubscriptions,
          isLoading: _isLoadingSnapshot,
          loadSubscriptions: _loadCustomerSubscriptions,
        ),
      ),
    );
  }

  Future<void> _openSalonSubscriptionsScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AdminSalonSubscriptionsScreen(
          salons: _adminSalons,
          isLoading: _isLoadingSnapshot,
          loadSalons: _loadAdminSalons,
        ),
      ),
    );
  }

  Future<List<Product>> _loadAdminProducts() async {
    final AdminSnapshot snapshot = await widget.platformRepository
        .loadAdminSnapshot();
    if (mounted) {
      setState(() => _applySnapshot(snapshot));
    }
    return snapshot.adminProducts;
  }

  Future<void> _openAdminProductsScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AdminProductsScreen(
          actor: widget.user,
          platformRepository: widget.platformRepository,
          products: _adminProducts,
          isLoading: _isLoadingSnapshot,
          loadProducts: _loadAdminProducts,
        ),
      ),
    );
  }

  Future<void> _openAdminProductOrdersScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AdminProductOrdersScreen(
          actor: widget.user,
          platformRepository: widget.platformRepository,
        ),
      ),
    );
  }

  Future<void> _openRevenueDetailsScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AdminRevenueDetailsScreen(
          metrics: _metrics,
          customerSubscriptions: _customerSubscriptions,
          salons: _adminSalons,
          products: _adminProducts,
        ),
      ),
    );
  }

  Future<void> _openActivityLogsScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AdminActivityLogsScreen(
          initialLogs: _activityLogs,
          loadLogs: () async {
            final AdminSnapshot snapshot = await widget.platformRepository
                .loadAdminSnapshot();
            if (mounted) {
              setState(() => _applySnapshot(snapshot));
            }
            return snapshot.activityLogs;
          },
        ),
      ),
    );
  }

  Future<void> _openRequestsTab() async {
    if (!mounted) {
      return;
    }
    _selectTab(1);
  }

  Future<void> _reviewRequest({
    required AdminSalonRequestRecord record,
    required SalonRequestStatus status,
    required String adminNote,
  }) async {
    await widget.platformRepository.reviewSalonRequest(
      record: record,
      status: status,
      adminNote: adminNote,
      admin: widget.user,
    );
    await _refreshSnapshot();
  }

  Future<void> _sendAdminNotification({
    required String audience,
    String? targetProfileId,
    String? targetSalonId,
    required String title,
    required String body,
  }) async {
    await widget.platformRepository.sendAdminNotification(
      actor: widget.user,
      title: title,
      body: body,
      audience: audience,
      targetProfileId: targetProfileId,
      targetSalonId: targetSalonId,
    );
  }

  Future<void> _openCouponsScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AdminCouponsScreen(
          coupons: _coupons,
          onSaveCoupon: (PromoCouponRecord coupon) async {
            final PromoCouponRecord saved = await widget.platformRepository
                .savePromoCoupon(coupon: coupon);
            await _refreshSnapshot();
            return saved;
          },
        ),
      ),
    );
  }

  Widget _buildPage(int index) {
    final int disabledAdminsCount = _admins
        .where((AdminTeamMember admin) => !admin.isActive)
        .length;
    switch (index) {
      case 0:
        return AdminDashboardScreen(
          currentAdmin: widget.user,
          canManageAdmins: widget.user.isAdminOwner,
          disabledAdminsCount: disabledAdminsCount,
          admins: _admins,
          coupons: _coupons,
          metrics: _metrics,
          users: _users,
          activityLogs: _activityLogs,
          isLoading: _isLoadingSnapshot,
          onOpenAdmins: _openAdminsScreen,
          onOpenCoupons: _openCouponsScreen,
          onOpenUsers: _openUsersScreen,
          onOpenSalons: _openSalonsScreen,
          onOpenRevenue: _openRevenueDetailsScreen,
          onOpenCustomerSubscriptions: _openCustomerSubscriptionsScreen,
          onOpenSalonSubscriptions: _openSalonSubscriptionsScreen,
          onOpenProducts: _openAdminProductsScreen,
          onOpenProductOrders: _openAdminProductOrdersScreen,
          onOpenActivityLogs: _openActivityLogsScreen,
          onOpenRequests: _openRequestsTab,
          onOpenAddAdmin: widget.user.isAdminOwner
              ? () => _openAdminEditor(null)
              : null,
          onRefresh: _refreshSnapshot,
        );
      case 1:
        return AdminRequestsScreen(
          requests: _requests,
          isLoading: _isLoadingSnapshot,
          onRefresh: _refreshSnapshot,
          onReviewRequest: _reviewRequest,
        );
      case 2:
        return AdminNotificationsScreen(
          users: _users,
          salons: _salons,
          isLoading: _isLoadingSnapshot,
          onSendNotification: _sendAdminNotification,
        );
      case 3:
        return AiStylistScreen(
          role: AppRole.admin,
          selectedLanguage: widget.selectedLanguage,
        );
      case 4:
        return AdminSettingsScreen(
          user: widget.user,
          platformRepository: widget.platformRepository,
          onUserChanged: widget.onUserChanged,
          onLogout: widget.onLogout,
          isDarkMode: widget.isDarkMode,
          onThemeChanged: widget.onThemeChanged,
          isHighContrast: widget.isHighContrast,
          onHighContrastChanged: widget.onHighContrastChanged,
          textScaleFactor: widget.textScaleFactor,
          onTextScaleChanged: widget.onTextScaleChanged,
          selectedLanguage: widget.selectedLanguage,
          onLanguageChanged: widget.onLanguageChanged,
          isBiometricLockEnabled: widget.isBiometricLockEnabled,
          onBiometricLockChanged: widget.onBiometricLockChanged,
        );
    }

    return const SizedBox.shrink();
  }

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
      _loadedPageIndexes.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<_NavItem> tabs = <_NavItem>[
      _NavItem(
        Icons.space_dashboard_outlined,
        _tr(context, 'Dashboard', 'لوحة التحكم'),
      ),
      _NavItem(Icons.approval_outlined, _tr(context, 'Requests', 'الطلبات')),
      _NavItem(
        Icons.notifications_active_outlined,
        _tr(context, 'Notify', 'الإشعارات'),
      ),
      _NavItem(Icons.auto_awesome_rounded, _tr(context, 'AI', 'الذكاء')),
      _NavItem(Icons.settings_rounded, _tr(context, 'Settings', 'الإعدادات')),
    ];

    return AppViewport(
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: List<Widget>.generate(tabs.length, (int index) {
            if (!_loadedPageIndexes.contains(index)) {
              return const SizedBox.shrink();
            }
            return _buildPage(index);
          }),
        ),
        bottomNavigationBar: _ManagementNavigationBar(
          tabs: tabs,
          currentIndex: _currentIndex,
          onSelect: _selectTab,
        ),
      ),
    );
  }
}

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({
    super.key,
    required this.currentAdmin,
    required this.canManageAdmins,
    required this.disabledAdminsCount,
    required this.admins,
    required this.coupons,
    required this.metrics,
    required this.users,
    required this.activityLogs,
    required this.isLoading,
    required this.onOpenAdmins,
    required this.onOpenCoupons,
    required this.onOpenUsers,
    required this.onOpenSalons,
    required this.onOpenRevenue,
    required this.onOpenCustomerSubscriptions,
    required this.onOpenSalonSubscriptions,
    required this.onOpenProducts,
    required this.onOpenProductOrders,
    required this.onOpenActivityLogs,
    required this.onOpenRequests,
    this.onOpenAddAdmin,
    required this.onRefresh,
  });

  final AppUser currentAdmin;
  final bool canManageAdmins;
  final int disabledAdminsCount;
  final List<AdminTeamMember> admins;
  final List<PromoCouponRecord> coupons;
  final AdminDashboardMetrics metrics;
  final List<ManagedUserRecord> users;
  final List<AdminActivityLogRecord> activityLogs;
  final bool isLoading;
  final Future<void> Function() onOpenAdmins;
  final Future<void> Function() onOpenCoupons;
  final Future<void> Function() onOpenUsers;
  final Future<void> Function() onOpenSalons;
  final Future<void> Function() onOpenRevenue;
  final Future<void> Function() onOpenCustomerSubscriptions;
  final Future<void> Function() onOpenSalonSubscriptions;
  final Future<void> Function() onOpenProducts;
  final Future<void> Function() onOpenProductOrders;
  final Future<void> Function() onOpenActivityLogs;
  final Future<void> Function() onOpenRequests;
  final Future<void> Function()? onOpenAddAdmin;
  final Future<void> Function({bool showLoading}) onRefresh;

  @override
  Widget build(BuildContext context) {
    final List<ManagedUserRecord> visibleUsers = users
        .where((ManagedUserRecord user) => user.role == AppRole.customer)
        .toList(growable: false);
    final int activeCouponsCount = coupons
        .where(
          (PromoCouponRecord coupon) =>
              coupon.isActive && coupon.isAvailableAt(DateTime.now()),
        )
        .length;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: <Widget>[
          Text(
            _tr(context, 'Admin Dashboard', 'لوحة تحكم الإدارة'),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            canManageAdmins
                ? _tr(
                    context,
                    'Live platform overview for users, salons, admins, payments, and latest actions.',
                    'نظرة مباشرة على المستخدمين والصالونات والمدراء والمدفوعات وآخر النشاطات.',
                  )
                : _tr(
                    context,
                    'Live platform overview for users, salons, payments, and latest actions.',
                    'نظرة مباشرة على المستخدمين والصالونات والمدفوعات وآخر النشاطات.',
                  ),
            style: TextStyle(color: AppPalette.mutedForeground),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: appCardDecoration(),
            child: Row(
              children: <Widget>[
                _ManagementAvatar(
                  imagePath: currentAdmin.avatarPath,
                  radius: 32,
                  icon: Icons.admin_panel_settings_rounded,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        currentAdmin.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentAdmin.email,
                        style: TextStyle(color: AppPalette.mutedForeground),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentAdmin.isAdminOwner
                            ? _tr(
                                context,
                                'Admin owner account',
                                'حساب مالك الإدارة',
                              )
                            : _tr(context, 'Admin account', 'حساب إداري'),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppPalette.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.payments_outlined,
                  label: _tr(context, 'Revenue', 'الإيرادات'),
                  value: 'BHD ${metrics.totalRevenue.toStringAsFixed(2)}',
                  onTap: () => onOpenRevenue(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.people_alt_outlined,
                  label: _tr(context, 'Users', 'المستخدمون'),
                  value: '${visibleUsers.length}',
                  onTap: () => onOpenUsers(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.storefront_outlined,
                  label: _tr(context, 'Salons', 'الصالونات'),
                  value: '${metrics.salonCount}',
                  onTap: () => onOpenSalons(),
                ),
              ),
              if (canManageAdmins) ...<Widget>[
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.admin_panel_settings_outlined,
                    label: _tr(context, 'Admins', 'المدراء'),
                    value: '${admins.length}',
                    onTap: () => onOpenAdmins(),
                  ),
                ),
              ],
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.local_offer_outlined,
                  label: _tr(context, 'Coupons', 'الكوبونات'),
                  value: '$activeCouponsCount',
                  onTap: () => onOpenCoupons(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.workspace_premium_outlined,
                  label: _tr(context, 'User Subs', 'اشتراكات العملاء'),
                  value: '${metrics.customerSubscriptionCount}',
                  onTap: () => onOpenCustomerSubscriptions(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.store_mall_directory_outlined,
                  label: _tr(context, 'Salon Subs', 'اشتراكات الصالونات'),
                  value: '${metrics.salonSubscriptionCount}',
                  onTap: () => onOpenSalonSubscriptions(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.approval_outlined,
                  label: _tr(context, 'Requests', 'الطلبات'),
                  value: '${metrics.requestCount}',
                  onTap: () => onOpenRequests(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.inventory_2_outlined,
                  label: _tr(context, 'Orders', 'الطلبات'),
                  value: '${metrics.productOrderCount}',
                  onTap: () => onOpenProductOrders(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.shopping_bag_outlined,
                  label: _tr(context, 'Products', 'المنتجات'),
                  value: '${metrics.productCount}',
                  onTap: () => onOpenProducts(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.history_rounded,
                  label: _tr(context, 'Log History', 'سجل النشاط'),
                  value: '${activityLogs.length}',
                  onTap: () => onOpenActivityLogs(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: appCardDecoration(),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _tr(context, 'Coupons & Offers', 'الكوبونات والعروض'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _tr(
                          context,
                          '$activeCouponsCount active now · ${coupons.length} total codes ready for the app.',
                          '$activeCouponsCount كوبون مفعل الآن · ${coupons.length} كود جاهز للتطبيق.',
                        ),
                        style: TextStyle(color: AppPalette.mutedForeground),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 96,
                  child: FilledButton(
                    onPressed: () => onOpenCoupons(),
                    child: Text(_tr(context, 'Open', 'فتح')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: appCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _tr(context, 'Latest Users', 'أحدث المستخدمين'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: isLoading ? null : () => onRefresh(),
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (isLoading)
                  const LinearProgressIndicator(minHeight: 3)
                else if (visibleUsers.isEmpty)
                  Text(
                    _tr(
                      context,
                      'No users found yet.',
                      'لا يوجد مستخدمون بعد.',
                    ),
                  )
                else
                  ...visibleUsers.take(4).map((ManagedUserRecord user) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => onOpenUsers(),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: appCardDecoration(
                            color: AppPalette.background,
                            radius: 22,
                          ),
                          child: Row(
                            children: <Widget>[
                              _ManagementAvatar(
                                radius: 24,
                                imagePath: user.avatarUrl,
                                icon: user.role.avatarFallbackIcon,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      user.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${user.city} · ${user.role.localizedLabel(context)} · ${_localizedDisplayText(context, user.statusLabel)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppPalette.mutedForeground,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Spent BHD ${user.totalSpent.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppPalette.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                if (!isLoading && visibleUsers.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => onOpenUsers(),
                      child: const Text('Open Users'),
                    ),
                  ),
              ],
            ),
          ),
          if (canManageAdmins) ...<Widget>[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Admin Team Activity',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '$disabledAdminsCount disabled',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppPalette.mutedForeground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (onOpenAddAdmin != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: () => onOpenAddAdmin!(),
                        icon: const Icon(Icons.person_add_alt_rounded),
                        label: const Text('Add Admin'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  ...admins.map((AdminTeamMember admin) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: <Widget>[
                          CircleAvatar(
                            radius: 20,
                            foregroundImage: _appImageProvider(
                              admin.avatarPath,
                            ),
                            onForegroundImageError: (_, _) {},
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  admin.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  admin.lastAction,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppPalette.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

IconData _adminActivityIcon(String actionType) {
  final String normalized = actionType.toLowerCase();
  if (normalized.contains('product')) {
    return Icons.shopping_bag_outlined;
  }
  if (normalized.contains('subscription')) {
    return Icons.workspace_premium_outlined;
  }
  if (normalized.contains('request') || normalized.contains('salon')) {
    return Icons.storefront_outlined;
  }
  if (normalized.contains('payment') ||
      normalized.contains('booking') ||
      normalized.contains('order')) {
    return Icons.payments_outlined;
  }
  if (normalized.contains('admin')) {
    return Icons.admin_panel_settings_outlined;
  }
  if (normalized.contains('user')) {
    return Icons.people_alt_outlined;
  }
  return Icons.history_rounded;
}

class _AdminActivityLogTile extends StatelessWidget {
  const _AdminActivityLogTile({required this.log});

  final AdminActivityLogRecord log;

  @override
  Widget build(BuildContext context) {
    final Widget content = Container(
      padding: const EdgeInsets.all(14),
      decoration: appCardDecoration(color: AppPalette.background, radius: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppPalette.secondary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _adminActivityIcon(log.actionType),
              color: AppPalette.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        log.actorName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatNotificationTimestamp(log.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppPalette.mutedForeground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${log.actorRole.localizedLabel(context)} · ${log.actorEmail}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppPalette.mutedForeground,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(log.summary),
                if ((log.targetTable ?? '').trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    'Target: ${log.targetTable}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppPalette.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return content;
  }
}

class AdminActivityLogsScreen extends StatefulWidget {
  const AdminActivityLogsScreen({
    super.key,
    required this.initialLogs,
    required this.loadLogs,
  });

  final List<AdminActivityLogRecord> initialLogs;
  final Future<List<AdminActivityLogRecord>> Function() loadLogs;

  @override
  State<AdminActivityLogsScreen> createState() =>
      _AdminActivityLogsScreenState();
}

class _AdminActivityLogsScreenState extends State<AdminActivityLogsScreen> {
  String _query = '';
  late List<AdminActivityLogRecord> _logs = List<AdminActivityLogRecord>.from(
    widget.initialLogs,
  );
  bool _isRefreshing = false;

  List<AdminActivityLogRecord> get _filteredLogs {
    final String normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return _logs;
    }
    return _logs
        .where((AdminActivityLogRecord log) {
          final String haystack = <String>[
            log.actorName,
            log.actorEmail,
            log.actorRole.localizedLabel(context),
            log.actionType,
            log.summary,
            log.targetTable ?? '',
          ].join(' ').toLowerCase();
          return haystack.contains(normalizedQuery);
        })
        .toList(growable: false);
  }

  Future<void> _refreshLogs() async {
    setState(() => _isRefreshing = true);
    try {
      final List<AdminActivityLogRecord> refreshedLogs = await widget
          .loadLogs();
      if (!mounted) {
        return;
      }
      setState(() => _logs = refreshedLogs);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<AdminActivityLogRecord> logs = _filteredLogs;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log History'),
        actions: <Widget>[
          IconButton(
            onPressed: _isRefreshing ? null : _refreshLogs,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: <Widget>[
            TextField(
              onChanged: (String value) {
                setState(() => _query = value);
              },
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search actor, action, target, or summary',
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '${logs.length} item(s) shown',
              style: TextStyle(color: AppPalette.mutedForeground),
            ),
            const SizedBox(height: 14),
            if (_isRefreshing && _logs.isEmpty)
              const LinearProgressIndicator(minHeight: 3)
            else if (logs.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: appCardDecoration(),
                child: Text(
                  _query.trim().isEmpty
                      ? 'No log entries yet.'
                      : 'No log entries match this search.',
                  style: TextStyle(color: AppPalette.mutedForeground),
                ),
              )
            else
              ...logs.map((AdminActivityLogRecord log) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AdminActivityLogTile(log: log),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({
    super.key,
    required this.adminUser,
    required this.users,
    required this.loadUsers,
    required this.onSaveUser,
    required this.onToggleUser,
  });

  final AppUser adminUser;
  final List<ManagedUserRecord> users;
  final Future<List<ManagedUserRecord>> Function() loadUsers;
  final Future<void> Function({
    required ManagedUserRecord user,
    required String name,
    required String email,
    required String phone,
    required String city,
    required AppRole role,
  })
  onSaveUser;
  final Future<void> Function({required String userId, required bool isActive})
  onToggleUser;

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late List<ManagedUserRecord> _users = List<ManagedUserRecord>.from(
    widget.users,
  );
  final TextEditingController _searchController = TextEditingController();
  bool _isRefreshing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ManagedUserRecord> get _customerUsers => _users
      .where((ManagedUserRecord user) => user.role == AppRole.customer)
      .toList(growable: false);

  List<ManagedUserRecord> get _filteredUsers {
    final String query = _searchController.text.trim().toLowerCase();
    final List<ManagedUserRecord> filtered =
        _customerUsers
            .where((ManagedUserRecord user) {
              if (query.isEmpty) {
                return true;
              }
              final String haystack = '${user.name} ${user.email} ${user.phone}'
                  .toLowerCase();
              return haystack.contains(query);
            })
            .toList(growable: false)
          ..sort(
            (ManagedUserRecord a, ManagedUserRecord b) =>
                a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    return filtered;
  }

  Future<void> _editUser(BuildContext context, ManagedUserRecord user) async {
    final _AdminUserEditResult? result = await Navigator.of(context)
        .push<_AdminUserEditResult>(
          MaterialPageRoute<_AdminUserEditResult>(
            builder: (BuildContext context) => AdminUserEditorScreen(
              existing: user,
              canAssignAdminRole:
                  widget.adminUser.isAdminOwner || user.role == AppRole.admin,
              allowRoleEditing: false,
            ),
          ),
        );

    if (result == null || !context.mounted) {
      return;
    }

    try {
      await widget.onSaveUser(
        user: user,
        name: result.name,
        email: result.email,
        phone: result.phone,
        city: result.city,
        role: result.role,
      );
      if (!context.mounted) {
        return;
      }
      setState(() {
        final int index = _users.indexWhere(
          (ManagedUserRecord item) => item.id == user.id,
        );
        if (index >= 0) {
          _users[index] = _users[index].copyWith(
            name: result.name,
            email: result.email,
            phone: result.phone,
            city: result.city,
            role: result.role,
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.name} updated successfully.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  Future<void> _toggleUser(BuildContext context, ManagedUserRecord user) async {
    try {
      await widget.onToggleUser(userId: user.id, isActive: !user.isActive);
      if (!context.mounted) {
        return;
      }
      setState(() {
        final int index = _users.indexWhere(
          (ManagedUserRecord item) => item.id == user.id,
        );
        if (index >= 0) {
          _users[index] = _users[index].copyWith(isActive: !user.isActive);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            user.isActive
                ? '${user.name} was disabled.'
                : '${user.name} was enabled.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  Future<void> _refreshUsers() async {
    setState(() => _isRefreshing = true);
    try {
      final List<ManagedUserRecord> refreshedUsers = await widget.loadUsers();
      if (!mounted) {
        return;
      }
      setState(() => _users = refreshedUsers);
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<ManagedUserRecord> filteredUsers = _filteredUsers;
    final bool hasSearchQuery = _searchController.text.trim().isNotEmpty;
    final int totalCustomers = _customerUsers.length;

    return AppViewport(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Customers'),
          actions: <Widget>[
            IconButton(
              onPressed: _isRefreshing ? null : _refreshUsers,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Search name, phone, or email',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: hasSearchQuery
                        ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close_rounded),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Customers',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '$totalCustomers total',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppPalette.mutedForeground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_isRefreshing)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: filteredUsers.isEmpty
                      ? _EmptyStateCard(
                          icon: Icons.people_outline_rounded,
                          title: hasSearchQuery
                              ? 'No matches found'
                              : 'No customers found',
                          message: hasSearchQuery
                              ? 'Try another name, phone number, or email.'
                              : 'Freshline will show customer accounts here once they are available.',
                          actionLabel: hasSearchQuery ? 'Clear Search' : null,
                          onAction: hasSearchQuery
                              ? () {
                                  _searchController.clear();
                                  setState(() {});
                                }
                              : null,
                        )
                      : ListView.separated(
                          itemCount: filteredUsers.length,
                          separatorBuilder: (BuildContext context, int index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (BuildContext context, int index) {
                            final ManagedUserRecord user = filteredUsers[index];
                            return Container(
                              padding: const EdgeInsets.all(18),
                              decoration: appCardDecoration(),
                              child: Column(
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      _ManagementAvatar(
                                        radius: 24,
                                        imagePath: user.avatarUrl,
                                        icon: user.role.avatarFallbackIcon,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              user.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${user.role.localizedLabel(context)} · ${_localizedDisplayText(context, user.statusLabel)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: user.isActive
                                                    ? AppPalette.primary
                                                    : AppPalette
                                                          .mutedForeground,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              user.email,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    AppPalette.mutedForeground,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _AccountInfoRow(
                                    label: 'Phone',
                                    value: user.phone,
                                  ),
                                  const SizedBox(height: 8),
                                  _AccountInfoRow(
                                    label: 'City',
                                    value: user.city,
                                  ),
                                  const SizedBox(height: 8),
                                  _AccountInfoRow(
                                    label: 'Bookings',
                                    value: '${user.bookingsCount}',
                                  ),
                                  const SizedBox(height: 8),
                                  _AccountInfoRow(
                                    label: 'Orders',
                                    value: '${user.productOrdersCount}',
                                  ),
                                  const SizedBox(height: 8),
                                  _AccountInfoRow(
                                    label: 'Spent',
                                    value:
                                        'BHD ${user.totalSpent.toStringAsFixed(2)}',
                                  ),
                                  const SizedBox(height: 8),
                                  _AccountInfoRow(
                                    label: 'Points',
                                    value: '${user.loyaltyPoints}',
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () =>
                                              _editUser(context, user),
                                          child: const Text('Edit'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: () =>
                                              _toggleUser(context, user),
                                          child: Text(
                                            user.isActive
                                                ? 'Disable'
                                                : 'Enable',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminUserEditorScreen extends StatefulWidget {
  const AdminUserEditorScreen({
    super.key,
    required this.existing,
    required this.canAssignAdminRole,
    this.allowRoleEditing = true,
  });

  final ManagedUserRecord existing;
  final bool canAssignAdminRole;
  final bool allowRoleEditing;

  @override
  State<AdminUserEditorScreen> createState() => _AdminUserEditorScreenState();
}

class _AdminUserEditorScreenState extends State<AdminUserEditorScreen> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.existing.name,
  );
  late final TextEditingController _emailController = TextEditingController(
    text: widget.existing.email,
  );
  late final TextEditingController _phoneController = TextEditingController(
    text:
        normalizeBahrainPhone(widget.existing.phone, allowEmpty: true) ??
        widget.existing.phone.trim(),
  );
  late final TextEditingController _cityController = TextEditingController(
    text: normalizeBahrainLocation(widget.existing.city),
  );
  late AppRole _role = widget.existing.role;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and email are required.')),
      );
      return;
    }
    final String? phoneError = validateRequiredBahrainPhone(
      _phoneController.text,
    );
    if (phoneError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(phoneError)));
      return;
    }

    if (_role == AppRole.admin && !widget.canAssignAdminRole) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the admin owner can add a new admin.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _AdminUserEditResult(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: normalizeBahrainPhoneOrThrow(_phoneController.text),
        city: normalizeBahrainLocation(_cityController.text),
        role: _role,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: const Text('Edit User')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: appCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _AuthTextField(controller: _nameController, label: 'Full Name'),
                const SizedBox(height: 14),
                _AuthTextField(
                  controller: _emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                _AuthTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  keyboardType: TextInputType.phone,
                  inputFormatters: bahrainPhoneInputFormatters,
                ),
                const SizedBox(height: 14),
                _BahrainLocationDropdownField(
                  controller: _cityController,
                  label: 'City',
                ),
                const SizedBox(height: 14),
                if (widget.allowRoleEditing)
                  DropdownButtonFormField<AppRole>(
                    initialValue: _role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: AppRole.values
                        .where(
                          (AppRole role) =>
                              widget.canAssignAdminRole ||
                              role != AppRole.admin,
                        )
                        .map(
                          (AppRole role) => DropdownMenuItem<AppRole>(
                            value: role,
                            child: Text(role.localizedLabel(context)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (AppRole? value) {
                      if (value != null) {
                        setState(() => _role = value);
                      }
                    },
                  )
                else
                  _AccountInfoRow(
                    label: 'Role',
                    value: _role.localizedLabel(context),
                  ),
                if (widget.allowRoleEditing &&
                    !widget.canAssignAdminRole) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    'Only the admin owner can assign the Admin role.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminUserEditResult {
  const _AdminUserEditResult({
    required this.name,
    required this.email,
    required this.phone,
    required this.city,
    required this.role,
  });

  final String name;
  final String email;
  final String phone;
  final String city;
  final AppRole role;
}

class AdminEditorScreen extends StatefulWidget {
  const AdminEditorScreen({
    super.key,
    required this.actor,
    required this.platformRepository,
    this.existing,
  });

  final AppUser actor;
  final PlatformRepository platformRepository;
  final AdminTeamMember? existing;

  @override
  State<AdminEditorScreen> createState() => _AdminEditorScreenState();
}

class _AdminEditorScreenState extends State<AdminEditorScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _emailController = TextEditingController(
    text: widget.existing?.email ?? '',
  );
  late final TextEditingController _phoneController = TextEditingController(
    text:
        normalizeBahrainPhone(widget.existing?.phone, allowEmpty: true) ??
        (widget.existing?.phone ?? '').trim(),
  );
  late final TextEditingController _cityController = TextEditingController(
    text: normalizeBahrainLocation(widget.existing?.city ?? 'Manama'),
  );
  final TextEditingController _passwordController = TextEditingController();
  late String _avatarPath =
      widget.existing?.avatarPath.trim().isNotEmpty == true
      ? widget.existing!.avatarPath
      : currentDefaultProfileImageUrl();
  bool _isSaving = false;
  bool _hidePassword = true;
  bool _isUploadingAvatar = false;
  late final String _draftProfileImageKey =
      widget.existing?.id ?? 'admin-${DateTime.now().millisecondsSinceEpoch}';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String get _profileImageKey {
    final String existingId = (widget.existing?.id ?? '').trim();
    if (existingId.isNotEmpty) {
      return existingId;
    }
    final String email = _emailController.text.trim();
    if (email.isNotEmpty) {
      return email;
    }
    final String name = _nameController.text.trim();
    if (name.isNotEmpty) {
      return name;
    }
    return _draftProfileImageKey;
  }

  Future<void> _uploadAvatar() async {
    setState(() => _isUploadingAvatar = true);
    try {
      final String? uploadedPath = await widget.platformRepository
          .pickAndUploadProfileImage(profileKey: _profileImageKey);
      if (!mounted || uploadedPath == null || uploadedPath.trim().isEmpty) {
        return;
      }
      setState(() => _avatarPath = uploadedPath.trim());
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (widget.existing == null && _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a password for the new admin account.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.platformRepository.saveAdminAccount(
        actor: widget.actor,
        adminId: widget.existing?.id,
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: normalizeBahrainPhoneOrThrow(_phoneController.text),
        city: normalizeBahrainLocation(_cityController.text),
        password: _passwordController.text.trim().isEmpty
            ? null
            : _passwordController.text.trim(),
        avatarPath: _avatarPath.trim().isEmpty
            ? currentDefaultProfileImageUrl()
            : _avatarPath.trim(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool editing = widget.existing != null;
    final bool isOwnerAccount = widget.existing?.isOwner == true;
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            editing
                ? (isOwnerAccount ? 'Edit Admin Owner' : 'Edit Admin')
                : 'Add Admin',
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: appCardDecoration(),
                child: Column(
                  children: <Widget>[
                    _ManagementAvatar(
                      imagePath: _avatarPath,
                      radius: 36,
                      icon: Icons.admin_panel_settings_outlined,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Admin profile image',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Optional. If you skip this, Freshline will use the default profile image.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppPalette.mutedForeground,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isUploadingAvatar
                                ? null
                                : _uploadAvatar,
                            icon: _isUploadingAvatar
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.photo_camera_outlined),
                            label: Text(
                              isDefaultProfileImageSelection(_avatarPath)
                                  ? 'Upload Photo'
                                  : 'Replace Photo',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextButton(
                            onPressed: _isUploadingAvatar
                                ? null
                                : () {
                                    setState(
                                      () => _avatarPath =
                                          currentDefaultProfileImageUrl(),
                                    );
                                  },
                            child: const Text('Use Default'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: appCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      editing
                          ? 'Update the admin account details.'
                          : 'Create a new platform admin account. Only the admin owner can add new admins.',
                      style: TextStyle(
                        color: AppPalette.mutedForeground,
                        height: 1.45,
                      ),
                    ),
                    if (isOwnerAccount) ...<Widget>[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: appCardDecoration(
                          color: AppPalette.background,
                          radius: 18,
                        ),
                        child: const Text(
                          'This account is the admin owner account.',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Full name'),
                      validator: (String? value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Enter the admin name.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      readOnly: isOwnerAccount,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        helperText: isOwnerAccount
                            ? 'Admin owner email stays fixed as admin.com.'
                            : null,
                      ),
                      validator: (String? value) {
                        final String normalized = (value ?? '').trim();
                        if (normalized.isEmpty ||
                            (!normalized.contains('@') &&
                                normalized != adminOwnerEmail)) {
                          return 'Enter a valid email.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: bahrainPhoneInputFormatters,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      validator: validateRequiredBahrainPhone,
                    ),
                    const SizedBox(height: 12),
                    _BahrainLocationDropdownField(
                      controller: _cityController,
                      label: 'City',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _hidePassword,
                      decoration: InputDecoration(
                        labelText: editing
                            ? 'New password (optional)'
                            : 'Password',
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() => _hidePassword = !_hidePassword);
                          },
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                      validator: (String? value) {
                        final String normalized = (value ?? '').trim();
                        if (!editing && normalized.isEmpty) {
                          return 'Enter a password.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      editing
                          ? 'Leave the password empty if you do not want to change it.'
                          : 'The new admin will use this password to sign in.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppPalette.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _save,
                        child: Text(
                          _isSaving
                              ? 'Saving...'
                              : (editing ? 'Save Changes' : 'Add Admin'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminSalonsScreen extends StatefulWidget {
  const AdminSalonsScreen({
    super.key,
    required this.salons,
    required this.isLoading,
    required this.loadSalons,
  });

  final List<AdminSalonRecord> salons;
  final bool isLoading;
  final Future<List<AdminSalonRecord>> Function() loadSalons;

  @override
  State<AdminSalonsScreen> createState() => _AdminSalonsScreenState();
}

class _AdminSalonsScreenState extends State<AdminSalonsScreen> {
  late List<AdminSalonRecord> _salons = List<AdminSalonRecord>.from(
    widget.salons,
  );
  final TextEditingController _searchController = TextEditingController();
  bool _isRefreshing = false;

  @override
  void didUpdateWidget(covariant AdminSalonsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isRefreshing) {
      _salons = List<AdminSalonRecord>.from(widget.salons);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    try {
      final List<AdminSalonRecord> salons = await widget.loadSalons();
      if (!mounted) {
        return;
      }
      setState(() => _salons = salons);
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<AdminSalonRecord> salons = List<AdminSalonRecord>.from(_salons)
      ..sort(
        (AdminSalonRecord a, AdminSalonRecord b) => a.salon
            .localizedName(context)
            .toLowerCase()
            .compareTo(b.salon.localizedName(context).toLowerCase()),
      );
    final String query = _searchController.text.trim().toLowerCase();
    final bool hasSearchQuery = query.isNotEmpty;
    final List<AdminSalonRecord> filteredSalons = salons
        .where((AdminSalonRecord record) {
          if (query.isEmpty) {
            return true;
          }
          final String haystack =
              '${record.salon.name} ${record.salon.localizedName(context)} '
                      '${record.salon.phone} ${record.salon.location} ${record.salon.localizedLocation(context)} '
                      '${record.ownerName} ${record.ownerEmail} ${record.ownerPhone}'
                  .toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
    final int activeSalons = salons
        .where((AdminSalonRecord salon) => salon.isActive)
        .length;
    final int homeServiceSalons = salons
        .where((AdminSalonRecord salon) => salon.salon.homeServiceAvailable)
        .length;
    final int subscribedSalons = salons
        .where((AdminSalonRecord salon) => salon.subscriptionStatus != null)
        .length;

    return AppViewport(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Salons'),
          actions: <Widget>[
            IconButton(
              onPressed: _isRefreshing ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Salon Directory',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Open any salon to see owner details, subscription status, contact information, and storefront health in one place.',
                    style: TextStyle(
                      height: 1.45,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                  if (_isRefreshing || widget.isLoading) ...<Widget>[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(minHeight: 3),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Search name, phone, or email',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: hasSearchQuery
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _MetricCard(
                      label: 'Total',
                      value: '${salons.length}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(label: 'Active', value: '$activeSalons'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      label: 'Subscribed',
                      value: '$subscribedSalons',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      label: 'Home Service',
                      value: '$homeServiceSalons',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (filteredSalons.isEmpty)
              _EmptyStateCard(
                icon: Icons.storefront_outlined,
                title: hasSearchQuery ? 'No matches found' : 'No salons yet',
                message: hasSearchQuery
                    ? 'Try another salon, owner, phone number, or email.'
                    : 'Approved salons will appear here once applications are completed.',
                actionLabel: hasSearchQuery ? 'Clear Search' : null,
                onAction: hasSearchQuery
                    ? () {
                        _searchController.clear();
                        setState(() {});
                      }
                    : null,
              )
            else
              ...filteredSalons.map((AdminSalonRecord record) {
                final SalonSubscriptionStatus? subscription =
                    record.subscriptionStatus;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) =>
                              AdminSalonDetailsScreen(record: record),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: appCardDecoration(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: _AppImage(
                              imagePath: record.salon.imagePath,
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      record.salon.localizedName(context),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${record.ownerName} · ${record.salon.localizedLocation(context)}',
                                      style: TextStyle(
                                        color: AppPalette.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              _CatalogStatusChip(
                                label: record.isActive ? 'Active' : 'Inactive',
                                backgroundColor: record.isActive
                                    ? AppPalette.primary.withValues(alpha: 0.14)
                                    : AppPalette.secondary,
                                foregroundColor: record.isActive
                                    ? AppPalette.primary
                                    : AppPalette.mutedForeground,
                              ),
                            ],
                          ),
                          if (record.salon.description
                              .trim()
                              .isNotEmpty) ...<Widget>[
                            const SizedBox(height: 12),
                            Text(
                              record.salon.localizedDescription(context),
                              style: TextStyle(
                                height: 1.45,
                                color: AppPalette.mutedForeground,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: <Widget>[
                              _CatalogMetaChip(
                                icon: Icons.phone_outlined,
                                label: record.salon.phone,
                              ),
                              _CatalogMetaChip(
                                icon: Icons.star_border_rounded,
                                label:
                                    '${record.salon.rating.toStringAsFixed(1)} (${record.salon.reviews})',
                              ),
                              _CatalogMetaChip(
                                icon: Icons.credit_card_outlined,
                                label: subscription == null
                                    ? 'No subscription'
                                    : '${subscription.cycle.localizedLabel(context)} ${formatBhd(subscription.amount)}',
                                emphasized: subscription != null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (BuildContext context) =>
                                        AdminSalonDetailsScreen(record: record),
                                  ),
                                );
                              },
                              child: const Text('Open Salon'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class AdminSalonDetailsScreen extends StatelessWidget {
  const AdminSalonDetailsScreen({super.key, required this.record});

  final AdminSalonRecord record;

  @override
  Widget build(BuildContext context) {
    final Salon salon = record.salon;
    final SalonSubscriptionStatus? subscription = record.subscriptionStatus;

    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: const Text('Salon Details')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: _AppImage(
                imagePath: salon.imagePath,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    salon.localizedName(context),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AccountInfoRow(label: 'Owner', value: record.ownerName),
                  const SizedBox(height: 8),
                  _AccountInfoRow(
                    label: 'Owner Email',
                    value: record.ownerEmail.isEmpty
                        ? 'Not available'
                        : record.ownerEmail,
                  ),
                  const SizedBox(height: 8),
                  _AccountInfoRow(
                    label: 'Owner Phone',
                    value: record.ownerPhone,
                  ),
                  const SizedBox(height: 8),
                  _AccountInfoRow(label: 'Salon Phone', value: salon.phone),
                  const SizedBox(height: 8),
                  _AccountInfoRow(
                    label: 'City',
                    value: salon.localizedLocation(context),
                  ),
                  const SizedBox(height: 8),
                  _AccountInfoRow(
                    label: 'Address',
                    value: (salon.address ?? '').trim().isEmpty
                        ? 'Not available'
                        : salon.localizedAddress(context),
                  ),
                  const SizedBox(height: 8),
                  _AccountInfoRow(label: 'Price Tier', value: salon.priceLabel),
                  const SizedBox(height: 8),
                  _AccountInfoRow(
                    label: 'Home Service',
                    value: salon.homeServiceAvailable ? 'Supported' : 'No',
                  ),
                  const SizedBox(height: 8),
                  _AccountInfoRow(
                    label: 'Rating',
                    value:
                        '${salon.rating.toStringAsFixed(1)} from ${salon.reviews} review(s)',
                  ),
                  const SizedBox(height: 8),
                  _AccountInfoRow(
                    label: 'Status',
                    value: record.isActive ? 'Active' : 'Inactive',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Subscription',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  if (subscription == null)
                    Text(
                      'This salon does not have an active subscription record yet.',
                      style: TextStyle(color: AppPalette.mutedForeground),
                    )
                  else ...<Widget>[
                    _AccountInfoRow(
                      label: 'Plan',
                      value: subscription.cycle.localizedLabel(context),
                    ),
                    const SizedBox(height: 8),
                    _AccountInfoRow(
                      label: 'Amount',
                      value: formatBhd(subscription.amount),
                    ),
                    const SizedBox(height: 8),
                    _AccountInfoRow(
                      label: 'Expires',
                      value: _adminDateLabel(
                        subscription.expiresAt,
                        fallback: 'Not set',
                      ),
                    ),
                    const SizedBox(height: 8),
                    _AccountInfoRow(
                      label: 'Auto Renew',
                      value: subscription.autoRenew ? 'On' : 'Off',
                    ),
                  ],
                ],
              ),
            ),
            if (salon.description.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: appCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'About',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      salon.localizedDescription(context),
                      style: TextStyle(
                        height: 1.45,
                        color: AppPalette.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AdminCustomerSubscriptionsScreen extends StatefulWidget {
  const AdminCustomerSubscriptionsScreen({
    super.key,
    required this.subscriptions,
    required this.isLoading,
    required this.loadSubscriptions,
  });

  final List<AdminCustomerSubscriptionRecord> subscriptions;
  final bool isLoading;
  final Future<List<AdminCustomerSubscriptionRecord>> Function()
  loadSubscriptions;

  @override
  State<AdminCustomerSubscriptionsScreen> createState() =>
      _AdminCustomerSubscriptionsScreenState();
}

class _AdminCustomerSubscriptionsScreenState
    extends State<AdminCustomerSubscriptionsScreen> {
  late List<AdminCustomerSubscriptionRecord> _subscriptions =
      List<AdminCustomerSubscriptionRecord>.from(widget.subscriptions);
  bool _isRefreshing = false;

  @override
  void didUpdateWidget(covariant AdminCustomerSubscriptionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isRefreshing) {
      _subscriptions = List<AdminCustomerSubscriptionRecord>.from(
        widget.subscriptions,
      );
    }
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    try {
      final List<AdminCustomerSubscriptionRecord> subscriptions = await widget
          .loadSubscriptions();
      if (!mounted) {
        return;
      }
      setState(() => _subscriptions = subscriptions);
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<AdminCustomerSubscriptionRecord> subscriptions =
        List<AdminCustomerSubscriptionRecord>.from(_subscriptions)..sort((
          AdminCustomerSubscriptionRecord a,
          AdminCustomerSubscriptionRecord b,
        ) {
          return a.user.name.toLowerCase().compareTo(b.user.name.toLowerCase());
        });
    final int autoRenewCount = subscriptions
        .where(
          (AdminCustomerSubscriptionRecord item) => item.subscription.autoRenew,
        )
        .length;
    final int bronzeCount = subscriptions
        .where(
          (AdminCustomerSubscriptionRecord item) =>
              item.subscription.plan.id == 'bronze',
        )
        .length;
    final int silverCount = subscriptions
        .where(
          (AdminCustomerSubscriptionRecord item) =>
              item.subscription.plan.id == 'silver',
        )
        .length;
    final int goldCount = subscriptions
        .where(
          (AdminCustomerSubscriptionRecord item) =>
              item.subscription.plan.id == 'gold',
        )
        .length;

    return AppViewport(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Customer Subscriptions'),
          actions: <Widget>[
            IconButton(
              onPressed: _isRefreshing ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Active Customer Plans',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'See who is subscribed, which plan they are on, and when each membership is due to end.',
                    style: TextStyle(
                      height: 1.45,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                  if (_isRefreshing || widget.isLoading) ...<Widget>[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(minHeight: 3),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _MetricCard(
                          label: 'Active',
                          value: '${subscriptions.length}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          label: 'Auto Renew',
                          value: '$autoRenewCount',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(label: 'Gold', value: '$goldCount'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _MetricCard(
                          label: 'Bronze',
                          value: '$bronzeCount',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          label: 'Silver',
                          value: '$silverCount',
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (subscriptions.isEmpty)
              const _EmptyStateCard(
                icon: Icons.workspace_premium_outlined,
                title: 'No customer subscriptions',
                message:
                    'Active customer plans will appear here after someone subscribes.',
              )
            else
              ...subscriptions.map((AdminCustomerSubscriptionRecord record) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: appCardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            _ManagementAvatar(
                              imagePath: record.user.avatarUrl,
                              radius: 24,
                              icon: Icons.person_outline_rounded,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    record.user.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    record.user.email,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppPalette.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _CatalogStatusChip(
                              label: record.subscription.plan.localizedName(
                                context,
                              ),
                              backgroundColor: AppPalette.primary.withValues(
                                alpha: 0.14,
                              ),
                              foregroundColor: AppPalette.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _AccountInfoRow(
                          label: 'Phone',
                          value: record.user.phone,
                        ),
                        const SizedBox(height: 8),
                        _AccountInfoRow(label: 'City', value: record.user.city),
                        const SizedBox(height: 8),
                        _AccountInfoRow(
                          label: 'Plan Price',
                          value: formatBhd(record.subscription.plan.price),
                        ),
                        const SizedBox(height: 8),
                        _AccountInfoRow(
                          label: 'Started',
                          value: _adminDateLabel(
                            record.subscription.startsAt,
                            fallback: 'Not set',
                          ),
                        ),
                        const SizedBox(height: 8),
                        _AccountInfoRow(
                          label: 'Ends',
                          value: _adminDateLabel(
                            record.subscription.endsAt,
                            fallback: 'Not set',
                          ),
                        ),
                        const SizedBox(height: 8),
                        _AccountInfoRow(
                          label: 'Auto Renew',
                          value: record.subscription.autoRenew ? 'On' : 'Off',
                        ),
                        const SizedBox(height: 8),
                        _AccountInfoRow(
                          label: 'Spent',
                          value: formatBhd(record.user.totalSpent),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class AdminSalonSubscriptionsScreen extends StatefulWidget {
  const AdminSalonSubscriptionsScreen({
    super.key,
    required this.salons,
    required this.isLoading,
    required this.loadSalons,
  });

  final List<AdminSalonRecord> salons;
  final bool isLoading;
  final Future<List<AdminSalonRecord>> Function() loadSalons;

  @override
  State<AdminSalonSubscriptionsScreen> createState() =>
      _AdminSalonSubscriptionsScreenState();
}

class _AdminSalonSubscriptionsScreenState
    extends State<AdminSalonSubscriptionsScreen> {
  late List<AdminSalonRecord> _salons = List<AdminSalonRecord>.from(
    widget.salons,
  );
  bool _isRefreshing = false;

  @override
  void didUpdateWidget(covariant AdminSalonSubscriptionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isRefreshing) {
      _salons = List<AdminSalonRecord>.from(widget.salons);
    }
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    try {
      final List<AdminSalonRecord> salons = await widget.loadSalons();
      if (!mounted) {
        return;
      }
      setState(() => _salons = salons);
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<AdminSalonRecord> salons =
        _salons
            .where((AdminSalonRecord salon) => salon.subscriptionStatus != null)
            .toList(growable: false)
          ..sort((AdminSalonRecord a, AdminSalonRecord b) {
            return a.salon
                .localizedName(context)
                .toLowerCase()
                .compareTo(b.salon.localizedName(context).toLowerCase());
          });
    final int monthlyCount = salons
        .where(
          (AdminSalonRecord salon) =>
              salon.subscriptionStatus?.cycle ==
              SubscriptionCycleOption.monthly,
        )
        .length;
    final int yearlyCount = salons
        .where(
          (AdminSalonRecord salon) =>
              salon.subscriptionStatus?.cycle == SubscriptionCycleOption.yearly,
        )
        .length;
    final int autoRenewCount = salons
        .where(
          (AdminSalonRecord salon) =>
              salon.subscriptionStatus?.autoRenew == true,
        )
        .length;

    return AppViewport(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Salon Subscriptions'),
          actions: <Widget>[
            IconButton(
              onPressed: _isRefreshing ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Active Salon Plans',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track which salon is on which subscription cycle, who owns it, and when the current billing period ends.',
                    style: TextStyle(
                      height: 1.45,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                  if (_isRefreshing || widget.isLoading) ...<Widget>[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(minHeight: 3),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _MetricCard(
                      label: 'Active',
                      value: '${salons.length}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      label: 'Monthly',
                      value: '$monthlyCount',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(label: 'Yearly', value: '$yearlyCount'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      label: 'Auto Renew',
                      value: '$autoRenewCount',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (salons.isEmpty)
              const _EmptyStateCard(
                icon: Icons.store_mall_directory_outlined,
                title: 'No salon subscriptions',
                message:
                    'Salon plans will appear here after a salon subscribes.',
              )
            else
              ...salons.map((AdminSalonRecord record) {
                final SalonSubscriptionStatus subscription =
                    record.subscriptionStatus!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: appCardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _AppImage(
                                imagePath: record.salon.imagePath,
                                height: 64,
                                width: 64,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    record.salon.localizedName(context),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${record.ownerName} · ${record.salon.localizedLocation(context)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppPalette.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _CatalogStatusChip(
                              label: subscription.cycle.localizedLabel(context),
                              backgroundColor: AppPalette.primary.withValues(
                                alpha: 0.14,
                              ),
                              foregroundColor: AppPalette.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _AccountInfoRow(
                          label: 'Owner Email',
                          value: record.ownerEmail.isEmpty
                              ? 'Not available'
                              : record.ownerEmail,
                        ),
                        const SizedBox(height: 8),
                        _AccountInfoRow(
                          label: 'Owner Phone',
                          value: record.ownerPhone,
                        ),
                        const SizedBox(height: 8),
                        _AccountInfoRow(
                          label: 'Amount',
                          value: formatBhd(subscription.amount),
                        ),
                        const SizedBox(height: 8),
                        _AccountInfoRow(
                          label: 'Expires',
                          value: _adminDateLabel(
                            subscription.expiresAt,
                            fallback: 'Not set',
                          ),
                        ),
                        const SizedBox(height: 8),
                        _AccountInfoRow(
                          label: 'Auto Renew',
                          value: subscription.autoRenew ? 'On' : 'Off',
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class AdminRevenueDetailsScreen extends StatelessWidget {
  const AdminRevenueDetailsScreen({
    super.key,
    required this.metrics,
    required this.customerSubscriptions,
    required this.salons,
    required this.products,
  });

  final AdminDashboardMetrics metrics;
  final List<AdminCustomerSubscriptionRecord> customerSubscriptions;
  final List<AdminSalonRecord> salons;
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final int outOfStockCount = products
        .where((Product product) => product.stock <= 0 || !product.isActive)
        .length;
    final int yearlySalons = salons
        .where(
          (AdminSalonRecord salon) =>
              salon.subscriptionStatus?.cycle == SubscriptionCycleOption.yearly,
        )
        .length;

    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: const Text('Revenue')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Platform Revenue',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This view combines paid customer subscriptions, salon subscriptions, product orders, and salon bookings into one admin breakdown.',
                    style: TextStyle(
                      height: 1.45,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    formatBhd(metrics.totalRevenue),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total collected revenue',
                    style: TextStyle(color: AppPalette.mutedForeground),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _MetricCard(
                          label: 'Customer Subs',
                          value: formatBhd(metrics.customerSubscriptionRevenue),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          label: 'Salon Subs',
                          value: formatBhd(metrics.salonSubscriptionRevenue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _MetricCard(
                          label: 'Product Orders',
                          value: formatBhd(metrics.productRevenue),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          label: 'Salon Bookings',
                          value: formatBhd(metrics.bookingRevenue),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Revenue Breakdown',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  _AccountInfoRow(
                    label: 'Customer subscriptions',
                    value: formatBhd(metrics.customerSubscriptionRevenue),
                  ),
                  const SizedBox(height: 8),
                  _AccountInfoRow(
                    label: 'Salon subscriptions',
                    value: formatBhd(metrics.salonSubscriptionRevenue),
                  ),
                  const SizedBox(height: 8),
                  _AccountInfoRow(
                    label: 'Product orders',
                    value: formatBhd(metrics.productRevenue),
                  ),
                  const SizedBox(height: 8),
                  _AccountInfoRow(
                    label: 'Salon bookings',
                    value: formatBhd(metrics.bookingRevenue),
                  ),
                  const SizedBox(height: 8),
                  _AccountInfoRow(
                    label: 'Total revenue',
                    value: formatBhd(metrics.totalRevenue),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Platform Activity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  _AccountInfoRow(
                    label: 'Subscribed customers',
                    value: '${customerSubscriptions.length}',
                  ),
                  const SizedBox(height: 8),
                  _AccountInfoRow(
                    label: 'Subscribed salons',
                    value: '${metrics.salonSubscriptionCount}',
                  ),
                  const SizedBox(height: 8),
                  _AccountInfoRow(
                    label: 'Yearly salon plans',
                    value: '$yearlySalons',
                  ),
                  const SizedBox(height: 8),
                  _AccountInfoRow(
                    label: 'Platform products',
                    value: '${products.length}',
                  ),
                  const SizedBox(height: 8),
                  _AccountInfoRow(
                    label: 'Out of stock products',
                    value: '$outOfStockCount',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({
    super.key,
    required this.actor,
    required this.platformRepository,
    required this.products,
    required this.isLoading,
    required this.loadProducts,
  });

  final AppUser actor;
  final PlatformRepository platformRepository;
  final List<Product> products;
  final bool isLoading;
  final Future<List<Product>> Function() loadProducts;

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  late List<Product> _products = List<Product>.from(widget.products);
  bool _isRefreshing = false;
  bool _isSubmitting = false;

  @override
  void didUpdateWidget(covariant AdminProductsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isRefreshing && !_isSubmitting) {
      _products = List<Product>.from(widget.products);
    }
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    try {
      final List<Product> products = await widget.loadProducts();
      if (!mounted) {
        return;
      }
      setState(() => _products = products);
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _openProductEditor([Product? existing]) async {
    final _SalonProductDraft? draft = await Navigator.of(context)
        .push<_SalonProductDraft>(
          MaterialPageRoute<_SalonProductDraft>(
            builder: (BuildContext context) => SalonProductEditorScreen(
              platformRepository: widget.platformRepository,
              title: existing == null ? 'Add Product' : 'Edit Product',
              name: existing?.name ?? '',
              category: existing?.category ?? '',
              description: existing?.description ?? '',
              price: existing == null ? '' : formatPrice(existing.price),
              stock: existing == null ? '0' : '${existing.stock}',
              isActive: existing?.isActive ?? true,
              initialImagePath:
                  existing?.imagePath ?? currentDefaultProductImageUrl(),
              submitLabel: existing == null ? 'Create Product' : 'Save Product',
            ),
          ),
        );
    if (draft == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.platformRepository.saveAdminProduct(
        actor: widget.actor,
        productId: existing?.id,
        name: draft.name,
        category: draft.category,
        description: draft.description,
        price: draft.price,
        stock: draft.stock,
        isActive: draft.isActive,
        salonId: existing?.salonId,
        imagePath: draft.imagePath,
      );
      if (!mounted) {
        return;
      }
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'Product created successfully.'
                : 'Product updated successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final bool shouldDelete = await _showActionConfirmationDialog(
      context: context,
      title: _tr(context, 'Delete Product', 'حذف المنتج'),
      message: _tr(
        context,
        'Remove ${product.localizedName(context)} from the customer product catalog?',
        'هل تريد حذف ${product.localizedName(context)} من كتالوج منتجات العملاء؟',
      ),
      confirmLabel: _tr(context, 'Delete', 'حذف'),
      isDestructive: true,
    );
    if (!shouldDelete) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.platformRepository.deleteAdminProduct(
        actor: widget.actor,
        productId: product.id,
      );
      if (!mounted) {
        return;
      }
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Product> products = List<Product>.from(_products)
      ..sort(
        (Product a, Product b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    final int liveProducts = products
        .where((Product product) => product.isActive && product.stock > 0)
        .length;
    final int outOfStockProducts = products
        .where((Product product) => product.stock <= 0 || !product.isActive)
        .length;

    return AppViewport(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Products'),
          actions: <Widget>[
            IconButton(
              onPressed: _isRefreshing ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Product Catalog',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () => unawaited(_openProductEditor()),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add Product'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'See every product customers can buy. New items you add here become platform products, while existing salon items stay linked to their salons.',
                    style: TextStyle(
                      height: 1.45,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                  if (_isRefreshing ||
                      widget.isLoading ||
                      _isSubmitting) ...<Widget>[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(minHeight: 3),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _MetricCard(
                      label: 'Total',
                      value: '${products.length}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(label: 'Live', value: '$liveProducts'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      label: 'Out Of Stock',
                      value: '$outOfStockProducts',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (products.isEmpty)
              _EmptyStateCard(
                icon: Icons.shopping_bag_outlined,
                title: 'No products yet',
                message:
                    'Add a product with image, name, description, and quantity to start selling it in the app.',
                actionLabel: 'Add Product',
                onAction: _isSubmitting
                    ? null
                    : () => unawaited(_openProductEditor()),
              )
            else
              ...products.map((Product product) {
                final bool outOfStock = product.stock <= 0 || !product.isActive;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: appCardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _AppImage(
                                imagePath: product.imagePath,
                                height: 80,
                                width: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    product.localizedName(context),
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    outOfStock
                                        ? 'Out of stock for customers'
                                        : 'Available in the product catalog',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: outOfStock
                                          ? AppPalette.mutedForeground
                                          : AppPalette.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (product.description
                                      .trim()
                                      .isNotEmpty) ...<Widget>[
                                    const SizedBox(height: 6),
                                    Text(
                                      product.localizedDescription(context),
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        height: 1.4,
                                        color: AppPalette.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _CatalogStatusChip(
                              label: outOfStock
                                  ? 'Out'
                                  : product.isActive
                                  ? 'Live'
                                  : 'Hidden',
                              backgroundColor: outOfStock
                                  ? AppPalette.secondary
                                  : AppPalette.primary.withValues(alpha: 0.14),
                              foregroundColor: outOfStock
                                  ? AppPalette.mutedForeground
                                  : AppPalette.primary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: <Widget>[
                            _CatalogMetaChip(
                              icon: Icons.category_outlined,
                              label: product.localizedCategory(context),
                            ),
                            _CatalogMetaChip(
                              icon: Icons.storefront_outlined,
                              label: product.salonId == null
                                  ? 'Platform product'
                                  : 'Salon product',
                            ),
                            _CatalogMetaChip(
                              icon: Icons.inventory_2_outlined,
                              label: product.stock <= 0
                                  ? 'Out of stock'
                                  : 'Stock ${product.stock}',
                            ),
                            _CatalogMetaChip(
                              icon: Icons.payments_outlined,
                              label: formatBhd(product.price),
                              emphasized: true,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => unawaited(
                                        _openProductEditor(product),
                                      ),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Edit'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => unawaited(_deleteProduct(product)),
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: const Text('Delete'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class AdminProductOrdersScreen extends StatefulWidget {
  const AdminProductOrdersScreen({
    super.key,
    required this.actor,
    required this.platformRepository,
  });

  final AppUser actor;
  final PlatformRepository platformRepository;

  @override
  State<AdminProductOrdersScreen> createState() =>
      _AdminProductOrdersScreenState();
}

class _AdminProductOrdersScreenState extends State<AdminProductOrdersScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<UserOrder> _orders = <UserOrder>[];
  bool _isLoading = true;
  _ManagementOrderSearchField _searchField = _ManagementOrderSearchField.phone;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final List<UserOrder> orders = await widget.platformRepository
          .loadAdminProductOrders(actor: widget.actor);
      if (!mounted) {
        return;
      }
      setState(() => _orders = orders);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openOrder(UserOrder order) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => ManagementProductOrderDetailsScreen(
          actor: widget.actor,
          platformRepository: widget.platformRepository,
          order: order,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _loadOrders();
    }
  }

  bool _matchesOrder(UserOrder order, String query) {
    if (query.isEmpty) {
      return true;
    }
    switch (_searchField) {
      case _ManagementOrderSearchField.phone:
        return (order.customerPhone ?? '').trim().toLowerCase().contains(query);
      case _ManagementOrderSearchField.invoice:
        return order.displayInvoiceNumber.toLowerCase().contains(query);
    }
  }

  Widget _buildProductOrderCard(UserOrder order) {
    final bool completed = _isManagementOrderCompleted(order);
    final bool isAvailable = order.isUnassignedProductOrder;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => unawaited(_openOrder(order)),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: appCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      order.serviceName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: completed
                          ? AppPalette.secondary
                          : isAvailable
                          ? const Color(0xFFD97706).withValues(alpha: 0.14)
                          : AppPalette.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      isAvailable && !completed
                          ? 'Available'
                          : order.statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: completed
                            ? AppPalette.foreground
                            : isAvailable
                            ? const Color(0xFFD97706)
                            : AppPalette.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _AccountInfoRow(
                label: 'Invoice',
                value: order.displayInvoiceNumber,
              ),
              const SizedBox(height: 8),
              _AccountInfoRow(
                label: 'Customer',
                value: order.customerName ?? 'Freshline Customer',
              ),
              if ((order.customerPhone ?? '').trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                _AccountInfoRow(label: 'Phone', value: order.customerPhone!),
              ],
              const SizedBox(height: 8),
              _AccountInfoRow(
                label: 'Ordered at',
                value: _formatBookingDateTime(order.scheduledAt),
              ),
              const SizedBox(height: 8),
              _AccountInfoRow(label: 'Assigned', value: order.employeeName),
              const SizedBox(height: 8),
              _AccountInfoRow(label: 'Total', value: formatBhd(order.total)),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  isAvailable && !completed ? 'Take order' : 'Open details',
                  style: TextStyle(
                    color: AppPalette.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String query = _searchController.text.trim().toLowerCase();
    final List<UserOrder> filteredOrders = _orders
        .where((UserOrder order) => _matchesOrder(order, query))
        .toList(growable: false);
    final List<UserOrder> activeOrders = filteredOrders
        .where((UserOrder order) => !_isManagementOrderCompleted(order))
        .toList(growable: false);
    final List<UserOrder> completedOrders = filteredOrders
        .where(_isManagementOrderCompleted)
        .toList(growable: false);

    return AppViewport(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Customer Product Orders'),
          actions: <Widget>[
            IconButton(
              onPressed: _isLoading ? null : _loadOrders,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Admin Order Queue',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Admins can review customer product orders here, take an available order, and mark it as delivered after handling it.',
                    style: TextStyle(
                      height: 1.45,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                  if (_isLoading) ...<Widget>[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(minHeight: 3),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: _searchField == _ManagementOrderSearchField.phone
                    ? 'Search by customer phone'
                    : 'Search by invoice number',
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _ManagementOrderSearchField.values
                  .map((_ManagementOrderSearchField field) {
                    return ChoiceChip(
                      label: Text(field.label),
                      selected: _searchField == field,
                      onSelected: (bool selected) {
                        if (!selected) {
                          return;
                        }
                        setState(() => _searchField = field);
                      },
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 16),
            if (filteredOrders.isEmpty)
              _EmptyStateCard(
                icon: Icons.inventory_2_outlined,
                title: 'No product orders found',
                message: query.isNotEmpty
                    ? 'No customer product orders match the current search.'
                    : 'Customer product orders will appear here when shoppers place them.',
              )
            else ...<Widget>[
              const _SectionLabel(
                title: 'Open & In Progress',
                subtitle:
                    'Available orders and the ones already taken by admins stay here.',
              ),
              const SizedBox(height: 12),
              if (activeOrders.isEmpty)
                _EmptyStateCard(
                  icon: Icons.inventory_outlined,
                  title: 'No open product orders',
                  message:
                      'Accepted and available product orders will show here.',
                )
              else
                ...activeOrders.map(_buildProductOrderCard),
              const SizedBox(height: 8),
              const _SectionLabel(
                title: 'Completed Product Orders',
                subtitle:
                    'Delivered product orders stay here for admin reference.',
              ),
              const SizedBox(height: 12),
              if (completedOrders.isEmpty)
                _EmptyStateCard(
                  icon: Icons.task_alt_rounded,
                  title: 'No completed product orders',
                  message:
                      'Delivered product orders will move here automatically.',
                )
              else
                ...completedOrders.map(_buildProductOrderCard),
            ],
          ],
        ),
      ),
    );
  }
}

String _adminDateLabel(DateTime? value, {String fallback = 'Not available'}) {
  if (value == null) {
    return fallback;
  }
  return formatCalendarDate(value);
}

String _adminDateTimeLabel(
  DateTime? value, {
  String fallback = 'Not available',
}) {
  if (value == null) {
    return fallback;
  }
  final DateTime local = value.toLocal();
  final int hour = local.hour == 0
      ? 12
      : local.hour > 12
      ? local.hour - 12
      : local.hour;
  final String minute = local.minute.toString().padLeft(2, '0');
  final String meridiem = local.hour >= 12 ? 'PM' : 'AM';
  return '${formatCalendarDate(local)} $hour:$minute $meridiem';
}

class AdminRequestsScreen extends StatelessWidget {
  const AdminRequestsScreen({
    super.key,
    required this.requests,
    required this.isLoading,
    required this.onRefresh,
    required this.onReviewRequest,
  });

  final List<AdminSalonRequestRecord> requests;
  final bool isLoading;
  final Future<void> Function({bool showLoading}) onRefresh;
  final Future<void> Function({
    required AdminSalonRequestRecord record,
    required SalonRequestStatus status,
    required String adminNote,
  })
  onReviewRequest;

  @override
  Widget build(BuildContext context) {
    final List<AdminSalonRequestRecord> pendingRequests = requests
        .where((AdminSalonRequestRecord record) => record.request.isEditable)
        .toList(growable: false);
    final List<AdminSalonRequestRecord> completedRequests = requests
        .where((AdminSalonRequestRecord record) => !record.request.isEditable)
        .toList(growable: false);

    return DefaultTabController(
      length: 2,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Salon Requests',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: isLoading
                        ? null
                        : () => onRefresh(showLoading: true),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${pendingRequests.length} pending requests',
                  style: TextStyle(color: AppPalette.mutedForeground),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: appCardDecoration(
                  color: AppPalette.secondary,
                  radius: 20,
                ),
                child: const TabBar(
                  tabs: <Tab>[
                    Tab(text: 'Pending'),
                    Tab(text: 'Completed'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: isLoading
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                      children: const <Widget>[
                        LinearProgressIndicator(minHeight: 3),
                      ],
                    )
                  : TabBarView(
                      children: <Widget>[
                        _AdminRequestList(
                          requests: pendingRequests,
                          emptyTitle: 'No pending requests',
                          emptyMessage:
                              'Pending and needs-info salon applications will appear here.',
                          onReviewRequest: onReviewRequest,
                        ),
                        _AdminRequestList(
                          requests: completedRequests,
                          emptyTitle: 'No completed requests',
                          emptyMessage:
                              'Approved and rejected salon applications will appear here.',
                          onReviewRequest: onReviewRequest,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminRequestList extends StatelessWidget {
  const _AdminRequestList({
    required this.requests,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onReviewRequest,
  });

  final List<AdminSalonRequestRecord> requests;
  final String emptyTitle;
  final String emptyMessage;
  final Future<void> Function({
    required AdminSalonRequestRecord record,
    required SalonRequestStatus status,
    required String adminNote,
  })
  onReviewRequest;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: <Widget>[
          _EmptyStateCard(
            icon: Icons.approval_outlined,
            title: emptyTitle,
            message: emptyMessage,
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
      children: requests
          .map((AdminSalonRequestRecord record) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          AdminRequestDetailsScreen(
                            record: record,
                            onReviewRequest: onReviewRequest,
                          ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: appCardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (record.request.salonImage != null) ...<Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: _AppImage(
                            imagePath: record.request.salonImage!.publicUrl,
                            height: 130,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      Row(
                        children: <Widget>[
                          _ManagementAvatar(
                            imagePath: record.ownerAvatarUrl,
                            radius: 20,
                            icon: Icons.person_outline_rounded,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  record.request.salonName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${record.ownerName} · ${record.request.city}',
                                  style: TextStyle(
                                    color: AppPalette.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _CatalogStatusChip(
                            label: record.request.status.localizedLabel(
                              context,
                            ),
                            backgroundColor: record.request.isEditable
                                ? AppPalette.primary.withValues(alpha: 0.14)
                                : AppPalette.secondary,
                            foregroundColor: record.request.isEditable
                                ? AppPalette.primary
                                : AppPalette.mutedForeground,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        record.ownerEmail,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppPalette.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        record.request.address,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppPalette.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        record.request.createdAt == null
                            ? 'Submitted recently'
                            : 'Submitted ${_adminDateTimeLabel(record.request.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppPalette.mutedForeground,
                        ),
                      ),
                      if (!record.request.isEditable &&
                          (record.reviewedByName ?? '')
                              .trim()
                              .isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          record.reviewedAt == null
                              ? 'Reviewed by ${record.reviewedByName}'
                              : 'Reviewed by ${record.reviewedByName} on ${_adminDateTimeLabel(record.reviewedAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppPalette.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (BuildContext context) =>
                                    AdminRequestDetailsScreen(
                                      record: record,
                                      onReviewRequest: onReviewRequest,
                                    ),
                              ),
                            );
                          },
                          child: Text(
                            record.request.isEditable
                                ? 'Review Request'
                                : 'Open Request',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class AdminRequestDetailsScreen extends StatefulWidget {
  const AdminRequestDetailsScreen({
    super.key,
    required this.record,
    required this.onReviewRequest,
  });

  final AdminSalonRequestRecord record;
  final Future<void> Function({
    required AdminSalonRequestRecord record,
    required SalonRequestStatus status,
    required String adminNote,
  })
  onReviewRequest;

  @override
  State<AdminRequestDetailsScreen> createState() =>
      _AdminRequestDetailsScreenState();
}

class _AdminRequestDetailsScreenState extends State<AdminRequestDetailsScreen> {
  late final TextEditingController _adminNoteController = TextEditingController(
    text: widget.record.request.adminNote ?? '',
  );
  bool _isSubmitting = false;

  @override
  void dispose() {
    _adminNoteController.dispose();
    super.dispose();
  }

  Future<void> _submitReview(SalonRequestStatus status) async {
    setState(() => _isSubmitting = true);
    try {
      await widget.onReviewRequest(
        record: widget.record,
        status: status,
        adminNote: _adminNoteController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.record.request.salonName} updated successfully.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final SalonRegistrationRequest request = widget.record.request;
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: const Text('Request Details')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: <Widget>[
            if (request.salonImage != null) ...<Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _AppImage(
                  imagePath: request.salonImage!.publicUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    request.salonName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _AccountInfoRow(
                    label: 'Owner',
                    value: widget.record.ownerName,
                  ),
                  const SizedBox(height: 8),
                  _AccountInfoRow(
                    label: 'Owner Email',
                    value: widget.record.ownerEmail,
                  ),
                  if (request.salonEmail.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    _AccountInfoRow(
                      label: 'Salon Email',
                      value: request.salonEmail,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _AccountInfoRow(
                    label: 'Owner Phone',
                    value: widget.record.ownerPhone,
                  ),
                  const SizedBox(height: 8),
                  _AccountInfoRow(
                    label: 'Salon Phone',
                    value: request.salonPhone,
                  ),
                  const SizedBox(height: 8),
                  _AccountInfoRow(label: 'City', value: request.city),
                  const SizedBox(height: 8),
                  _AccountInfoRow(label: 'Address', value: request.address),
                  const SizedBox(height: 8),
                  _AccountInfoRow(
                    label: 'Location',
                    value: request.locationUrl,
                  ),
                  if (request.websiteUrl != null &&
                      request.websiteUrl!.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    _AccountInfoRow(
                      label: 'Website',
                      value: request.websiteUrl!,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _AccountInfoRow(
                    label: 'Status',
                    value: request.status.localizedLabel(context),
                  ),
                  const SizedBox(height: 8),
                  _AccountInfoRow(
                    label: 'Submitted',
                    value: _adminDateTimeLabel(request.createdAt),
                  ),
                  if ((widget.record.reviewedByName ?? '')
                      .trim()
                      .isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    _AccountInfoRow(
                      label: 'Reviewed By',
                      value: widget.record.reviewedByName!,
                    ),
                    if ((widget.record.reviewedByEmail ?? '')
                        .trim()
                        .isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      _AccountInfoRow(
                        label: 'Reviewer Email',
                        value: widget.record.reviewedByEmail!,
                      ),
                    ],
                    const SizedBox(height: 8),
                    _AccountInfoRow(
                      label: 'Reviewed On',
                      value: _adminDateTimeLabel(widget.record.reviewedAt),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Files',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: request.commercialRegistration == null
                          ? null
                          : () => _launchUri(
                              context,
                              Uri.parse(
                                request.commercialRegistration!.publicUrl,
                              ),
                              'Could not open the commercial registration file.',
                              fallbackClipboardValue:
                                  request.commercialRegistration!.publicUrl,
                              fallbackConfirmation:
                                  'Commercial registration link copied.',
                            ),
                      child: const Text('Open Commercial Registration'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: request.governmentLicense == null
                          ? null
                          : () => _launchUri(
                              context,
                              Uri.parse(request.governmentLicense!.publicUrl),
                              'Could not open the government license file.',
                              fallbackClipboardValue:
                                  request.governmentLicense!.publicUrl,
                              fallbackConfirmation:
                                  'Government license link copied.',
                            ),
                      child: const Text('Open Government License'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: appCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Admin Note',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  _AuthTextField(
                    controller: _adminNoteController,
                    label: 'Admin Note',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () =>
                                    _submitReview(SalonRequestStatus.needsInfo),
                          child: const Text('Need Info'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isSubmitting
                              ? null
                              : () =>
                                    _submitReview(SalonRequestStatus.approved),
                          child: Text(_isSubmitting ? 'Saving...' : 'Approve'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => _submitReview(SalonRequestStatus.rejected),
                      child: const Text('Reject'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AdminNotificationAudience { allUsers, singleUser, allSalons, singleSalon }

extension _AdminNotificationAudienceMeta on _AdminNotificationAudience {
  String label(BuildContext context) {
    switch (this) {
      case _AdminNotificationAudience.allUsers:
        return _tr(context, 'All Users', 'كل العملاء');
      case _AdminNotificationAudience.singleUser:
        return _tr(context, 'Single User', 'عميل واحد');
      case _AdminNotificationAudience.allSalons:
        return _tr(context, 'All Salons', 'كل الصالونات');
      case _AdminNotificationAudience.singleSalon:
        return _tr(context, 'Single Salon', 'صالون واحد');
    }
  }

  String description(BuildContext context) {
    switch (this) {
      case _AdminNotificationAudience.allUsers:
        return _tr(
          context,
          'Every customer account will receive this notification.',
          'سيستلم كل حساب عميل هذا الإشعار.',
        );
      case _AdminNotificationAudience.singleUser:
        return _tr(
          context,
          'Only the selected customer will receive this notification.',
          'سيستلم العميل المحدد فقط هذا الإشعار.',
        );
      case _AdminNotificationAudience.allSalons:
        return _tr(
          context,
          'Every salon account will receive this notification.',
          'سيستلم كل حساب صالون هذا الإشعار.',
        );
      case _AdminNotificationAudience.singleSalon:
        return _tr(
          context,
          'Only the selected salon will receive this notification.',
          'سيستلم الصالون المحدد فقط هذا الإشعار.',
        );
    }
  }

  String get audienceValue {
    switch (this) {
      case _AdminNotificationAudience.allUsers:
        return 'all_users';
      case _AdminNotificationAudience.singleUser:
        return 'single_user';
      case _AdminNotificationAudience.allSalons:
        return 'all_salons';
      case _AdminNotificationAudience.singleSalon:
        return 'single_salon';
    }
  }

  bool get requiresUserTarget => this == _AdminNotificationAudience.singleUser;

  bool get requiresSalonTarget =>
      this == _AdminNotificationAudience.singleSalon;
}

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({
    super.key,
    required this.users,
    required this.salons,
    required this.isLoading,
    required this.onSendNotification,
  });

  final List<ManagedUserRecord> users;
  final List<Salon> salons;
  final bool isLoading;
  final Future<void> Function({
    required String audience,
    String? targetProfileId,
    String? targetSalonId,
    required String title,
    required String body,
  })
  onSendNotification;

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  _AdminNotificationAudience _selectedAudience =
      _AdminNotificationAudience.allUsers;
  String? _selectedUserId;
  String? _selectedSalonId;
  bool _isSending = false;

  List<ManagedUserRecord> get _customerRecipients {
    return widget.users
        .where(
          (ManagedUserRecord user) =>
              user.role == AppRole.customer && user.isActive,
        )
        .toList(growable: false)
      ..sort(
        (ManagedUserRecord a, ManagedUserRecord b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
  }

  List<Salon> get _salonRecipients {
    return List<Salon>.from(widget.salons)..sort(
      (Salon a, Salon b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _selectAudience(_AdminNotificationAudience audience) {
    setState(() {
      _selectedAudience = audience;
      if (!audience.requiresUserTarget) {
        _selectedUserId = null;
      }
      if (!audience.requiresSalonTarget) {
        _selectedSalonId = null;
      }
    });
  }

  Future<void> _submit() async {
    final String title = _titleController.text.trim();
    final String message = _messageController.text.trim();
    final List<ManagedUserRecord> customerRecipients = _customerRecipients;
    final List<Salon> salonRecipients = _salonRecipients;

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(context, 'Enter a notification title.', 'أدخل عنوان الإشعار.'),
          ),
        ),
      );
      return;
    }
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(context, 'Enter a notification message.', 'أدخل نص الإشعار.'),
          ),
        ),
      );
      return;
    }
    if (_selectedAudience.requiresUserTarget && _selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              context,
              'Choose the user who should receive it.',
              'اختر العميل الذي سيستلم الإشعار.',
            ),
          ),
        ),
      );
      return;
    }
    if (_selectedAudience.requiresSalonTarget && _selectedSalonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              context,
              'Choose the salon that should receive it.',
              'اختر الصالون الذي سيستلم الإشعار.',
            ),
          ),
        ),
      );
      return;
    }
    if (_selectedAudience.requiresUserTarget && customerRecipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              context,
              'There are no active users to notify yet.',
              'لا يوجد عملاء نشطون لإرسال إشعار لهم حالياً.',
            ),
          ),
        ),
      );
      return;
    }
    if (_selectedAudience.requiresSalonTarget && salonRecipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              context,
              'There are no salons to notify yet.',
              'لا توجد صالونات متاحة لإرسال إشعار لها حالياً.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      await widget.onSendNotification(
        audience: _selectedAudience.audienceValue,
        targetProfileId: _selectedUserId,
        targetSalonId: _selectedSalonId,
        title: title,
        body: message,
      );
      if (!mounted) {
        return;
      }
      _titleController.clear();
      _messageController.clear();
      setState(() {
        if (_selectedAudience.requiresUserTarget) {
          _selectedUserId = null;
        }
        if (_selectedAudience.requiresSalonTarget) {
          _selectedSalonId = null;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tr(
              context,
              '${_selectedAudience.label(context)} notification sent.',
              'تم إرسال إشعار ${_selectedAudience.label(context)}.',
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<ManagedUserRecord> customerRecipients = _customerRecipients;
    final List<Salon> salonRecipients = _salonRecipients;
    final bool canSend =
        !_isSending &&
        !widget.isLoading &&
        (!_selectedAudience.requiresUserTarget ||
            customerRecipients.isNotEmpty) &&
        (!_selectedAudience.requiresSalonTarget || salonRecipients.isNotEmpty);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: <Widget>[
          Text(
            _tr(context, 'Notifications', 'الإشعارات'),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: appCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _tr(context, 'Send platform message', 'إرسال رسالة للمنصة'),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  _tr(
                    context,
                    'Choose who should receive the notification, then send it to their in-app inbox.',
                    'اختر الجهة التي ستستلم الإشعار ثم أرسله مباشرة إلى صندوق الوارد داخل التطبيق.',
                  ),
                  style: TextStyle(
                    color: AppPalette.mutedForeground,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _AdminNotificationAudience.values
                      .map(
                        (_AdminNotificationAudience audience) => ChoiceChip(
                          label: Text(audience.label(context)),
                          selected: _selectedAudience == audience,
                          onSelected: (_) => _selectAudience(audience),
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 12),
                Text(
                  _selectedAudience.description(context),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppPalette.mutedForeground,
                  ),
                ),
                if (widget.isLoading) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    _tr(
                      context,
                      'Loading recipients...',
                      'جارٍ تحميل المستلمين...',
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppPalette.mutedForeground,
                    ),
                  ),
                ],
                if (_selectedAudience.requiresUserTarget) ...<Widget>[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String?>(
                      'notify-user-${_selectedUserId ?? 'none'}',
                    ),
                    initialValue: _selectedUserId,
                    decoration: InputDecoration(
                      labelText: _tr(context, 'Choose User', 'اختر العميل'),
                    ),
                    items: customerRecipients
                        .map(
                          (ManagedUserRecord user) => DropdownMenuItem<String>(
                            value: user.id,
                            child: Text('${user.name} - ${user.email}'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: widget.isLoading
                        ? null
                        : (String? value) {
                            setState(() => _selectedUserId = value);
                          },
                  ),
                  if (customerRecipients.isEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      _tr(
                        context,
                        'No active customers are available right now.',
                        'لا يوجد عملاء نشطون متاحون الآن.',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppPalette.mutedForeground,
                      ),
                    ),
                  ],
                ],
                if (_selectedAudience.requiresSalonTarget) ...<Widget>[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String?>(
                      'notify-salon-${_selectedSalonId ?? 'none'}',
                    ),
                    initialValue: _selectedSalonId,
                    decoration: InputDecoration(
                      labelText: _tr(context, 'Choose Salon', 'اختر الصالون'),
                    ),
                    items: salonRecipients
                        .map(
                          (Salon salon) => DropdownMenuItem<String>(
                            value: salon.id,
                            child: Text(
                              '${salon.localizedName(context)} - ${salon.localizedLocation(context)}',
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: widget.isLoading
                        ? null
                        : (String? value) {
                            setState(() => _selectedSalonId = value);
                          },
                  ),
                  if (salonRecipients.isEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      _tr(
                        context,
                        'No salons are available right now.',
                        'لا توجد صالونات متاحة الآن.',
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppPalette.mutedForeground,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                _AuthTextField(
                  controller: _titleController,
                  label: _tr(context, 'Notification Title', 'عنوان الإشعار'),
                ),
                const SizedBox(height: 14),
                _AuthTextField(
                  controller: _messageController,
                  label: _tr(context, 'Message', 'الرسالة'),
                  maxLines: 4,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: canSend ? _submit : null,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _isSending
                          ? _tr(context, 'Sending...', 'جارٍ الإرسال...')
                          : _tr(context, 'Send Notification', 'إرسال الإشعار'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminTeamScreen extends StatefulWidget {
  const AdminTeamScreen({
    super.key,
    required this.adminUser,
    required this.admins,
    required this.loadAdmins,
    required this.onEditAdmin,
    required this.onToggleAdmin,
  });

  final AppUser adminUser;
  final List<AdminTeamMember> admins;
  final Future<List<AdminTeamMember>> Function() loadAdmins;
  final Future<void> Function(AdminTeamMember? admin) onEditAdmin;
  final Future<void> Function(AdminTeamMember admin) onToggleAdmin;

  @override
  State<AdminTeamScreen> createState() => _AdminTeamScreenState();
}

class _AdminTeamScreenState extends State<AdminTeamScreen> {
  late List<AdminTeamMember> _admins = List<AdminTeamMember>.from(
    widget.admins,
  );
  final TextEditingController _searchController = TextEditingController();
  bool _isRefreshing = false;

  int get _disabledAdminsCount =>
      _admins.where((AdminTeamMember admin) => !admin.isActive).length;

  @override
  void didUpdateWidget(covariant AdminTeamScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isRefreshing) {
      _admins = List<AdminTeamMember>.from(widget.admins);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshAdmins() async {
    setState(() => _isRefreshing = true);
    try {
      final List<AdminTeamMember> refreshedAdmins = await widget.loadAdmins();
      if (!mounted) {
        return;
      }
      setState(() => _admins = refreshedAdmins);
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _openEditor(AdminTeamMember? admin) async {
    await widget.onEditAdmin(admin);
    if (!mounted) {
      return;
    }
    await _refreshAdmins();
  }

  Future<void> _toggleAdminStatus(AdminTeamMember admin) async {
    await widget.onToggleAdmin(admin);
    if (!mounted) {
      return;
    }
    await _refreshAdmins();
  }

  @override
  Widget build(BuildContext context) {
    final String query = _searchController.text.trim().toLowerCase();
    final bool hasSearchQuery = query.isNotEmpty;
    final List<AdminTeamMember> filteredAdmins = _admins
        .where((AdminTeamMember admin) {
          if (query.isEmpty) {
            return true;
          }
          final String haystack = '${admin.name} ${admin.email} ${admin.phone}'
              .toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Team'),
          actions: <Widget>[
            IconButton(
              onPressed: _isRefreshing ? null : _refreshAdmins,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: appCardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Admin Access',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.adminUser.isAdminOwner
                          ? 'Open any admin profile, update access, and add new admins from here.'
                          : 'Review the current admin team and their latest platform activity.',
                      style: TextStyle(
                        height: 1.45,
                        color: AppPalette.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _MetricCard(
                            label: 'Admins',
                            value: '${_admins.length}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            label: 'Disabled',
                            value: '$_disabledAdminsCount',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _MetricCard(
                            label: 'Role',
                            value: widget.adminUser.isAdminOwner
                                ? 'Owner'
                                : 'Admin',
                          ),
                        ),
                      ],
                    ),
                    if (widget.adminUser.isAdminOwner) ...<Widget>[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _openEditor(null),
                          icon: const Icon(Icons.person_add_alt_rounded),
                          label: const Text('Add Admin'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Search name, phone, or email',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: hasSearchQuery
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              if (filteredAdmins.isEmpty)
                _EmptyStateCard(
                  icon: Icons.admin_panel_settings_outlined,
                  title: hasSearchQuery ? 'No matches found' : 'No admins yet',
                  message: hasSearchQuery
                      ? 'Try another admin name, phone number, or email.'
                      : 'Freshline will show admin accounts here once they are available.',
                  actionLabel: hasSearchQuery
                      ? 'Clear Search'
                      : widget.adminUser.isAdminOwner
                      ? 'Add Admin'
                      : null,
                  onAction: hasSearchQuery
                      ? () {
                          _searchController.clear();
                          setState(() {});
                        }
                      : widget.adminUser.isAdminOwner
                      ? () => unawaited(_openEditor(null))
                      : null,
                )
              else
                ...filteredAdmins.map((AdminTeamMember admin) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: appCardDecoration(),
                      child: Column(
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              CircleAvatar(
                                radius: 24,
                                foregroundImage: _appImageProvider(
                                  admin.avatarPath,
                                ),
                                onForegroundImageError: (_, _) {},
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      admin.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: <Widget>[
                                        Text(
                                          admin.roleTitle,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppPalette.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (admin.isOwner)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppPalette.primary
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              'Owner',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppPalette.primary,
                                              ),
                                            ),
                                          ),
                                        if (!admin.isActive)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppPalette.border,
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              'Disabled',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    AppPalette.mutedForeground,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      admin.email,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppPalette.mutedForeground,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _AccountInfoRow(label: 'Phone', value: admin.phone),
                          const SizedBox(height: 8),
                          _AccountInfoRow(label: 'City', value: admin.city),
                          const SizedBox(height: 8),
                          _AccountInfoRow(
                            label: 'Last action',
                            value: admin.lastAction,
                          ),
                          if (widget.adminUser.isAdminOwner) ...<Widget>[
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => _openEditor(admin),
                                    child: const Text('Edit'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: admin.isOwner
                                        ? null
                                        : () => _toggleAdminStatus(admin),
                                    child: Text(
                                      admin.isActive ? 'Disable' : 'Enable',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({
    super.key,
    required this.user,
    required this.platformRepository,
    required this.onUserChanged,
    required this.onLogout,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.isHighContrast,
    required this.onHighContrastChanged,
    required this.textScaleFactor,
    required this.onTextScaleChanged,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    required this.isBiometricLockEnabled,
    required this.onBiometricLockChanged,
  });

  final AppUser user;
  final PlatformRepository platformRepository;
  final ValueChanged<AppUser> onUserChanged;
  final VoidCallback onLogout;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  final bool isHighContrast;
  final ValueChanged<bool> onHighContrastChanged;
  final double textScaleFactor;
  final ValueChanged<double> onTextScaleChanged;
  final String selectedLanguage;
  final ValueChanged<String> onLanguageChanged;
  final bool isBiometricLockEnabled;
  final AsyncBoolCallback onBiometricLockChanged;

  @override
  Widget build(BuildContext context) {
    final List<_SettingsItem> items = <_SettingsItem>[
      _SettingsItem(
        icon: Icons.person_outline_rounded,
        label: 'Account Details',
        subtitle: 'Update your admin profile, phone, city, and password',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => AccountDetailsScreen(
                user: user,
                platformRepository: platformRepository,
                onUserChanged: onUserChanged,
              ),
            ),
          );
        },
      ),
      if (user.isAdminOwner)
        _SettingsItem(
          icon: Icons.image_outlined,
          label: 'Default Images',
          subtitle:
              'Update the app-wide default profile, salon, and product images',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => PlatformDefaultImagesScreen(
                  actor: user,
                  platformRepository: platformRepository,
                ),
              ),
            );
          },
        ),
      _SettingsItem(
        icon: Icons.help_outline_rounded,
        label: 'Help & Support',
        subtitle: 'Admin FAQ, support channels, and guidance',
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) =>
                  const HelpSupportScreen(role: AppRole.admin),
            ),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.palette_outlined,
        label: _tr(context, 'Appearance & Language', 'المظهر واللغة'),
        subtitle: _tr(
          context,
          'Control contrast, font size, theme, and language for admin',
          'تحكم في التباين وحجم الخط والثيم واللغة للإدارة',
        ),
        onTap: () {
          showAppearanceSettingsSheet(
            context: context,
            isDarkMode: isDarkMode,
            onThemeChanged: onThemeChanged,
            isHighContrast: isHighContrast,
            onHighContrastChanged: onHighContrastChanged,
            textScaleFactor: textScaleFactor,
            onTextScaleChanged: onTextScaleChanged,
            selectedLanguage: selectedLanguage,
            onLanguageChanged: onLanguageChanged,
            subtitle: _tr(
              context,
              'Control contrast, font size, theme, and language for the admin workspace.',
              'تحكم في التباين وحجم الخط والثيم واللغة لمساحة الإدارة.',
            ),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.fingerprint_rounded,
        label: _tr(context, 'Biometric Lock', 'قفل البصمة'),
        subtitle: isBiometricLockEnabled
            ? _tr(
                context,
                'Enabled on this device for your saved session',
                'مفعل على هذا الجهاز لجلسة الدخول المحفوظة',
              )
            : _tr(
                context,
                'Use fingerprint or device biometrics before opening the app',
                'استخدم البصمة أو التحقق الحيوي قبل فتح التطبيق',
              ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => BiometricLockScreen(
                isEnabled: isBiometricLockEnabled,
                onChanged: onBiometricLockChanged,
              ),
            ),
          );
        },
      ),
      _SettingsItem(
        icon: Icons.logout_rounded,
        label: 'Log Out',
        subtitle: 'Return to sign in',
        danger: true,
        onTap: () {
          unawaited(_confirmLogoutRequested(context, onLogout));
        },
      ),
    ];

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: <Widget>[
          Text(
            _tr(context, 'Admin Settings', 'إعدادات الإدارة'),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: appCardDecoration(),
            child: Row(
              children: <Widget>[
                _ManagementAvatar(
                  imagePath: user.avatarPath,
                  radius: 30,
                  icon: Icons.admin_panel_settings_outlined,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(color: AppPalette.mutedForeground),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${user.isAdminOwner ? 'Admin owner' : 'Admin account'} · ${user.phone}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppPalette.mutedForeground,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: appCardDecoration(),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _MetricCard(
                    label: 'Role',
                    value: user.isAdminOwner ? 'Owner' : 'Admin',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'Theme',
                    value: isDarkMode ? 'Dark' : 'Light',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    label: 'Contrast',
                    value: isHighContrast ? 'High' : 'Default',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...items.map((_SettingsItem item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SettingsTile(item: item),
            );
          }),
        ],
      ),
    );
  }
}

class PlatformDefaultImagesScreen extends StatefulWidget {
  const PlatformDefaultImagesScreen({
    super.key,
    required this.actor,
    required this.platformRepository,
  });

  final AppUser actor;
  final PlatformRepository platformRepository;

  @override
  State<PlatformDefaultImagesScreen> createState() =>
      _PlatformDefaultImagesScreenState();
}

class _PlatformDefaultImagesScreenState
    extends State<PlatformDefaultImagesScreen> {
  late PlatformMediaDefaults _defaults = currentPlatformMediaDefaults;
  bool _isLoading = true;
  bool _isSaving = false;
  PlatformMediaType? _uploadingType;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDefaults());
  }

  Future<void> _loadDefaults() async {
    try {
      final PlatformMediaDefaults defaults = await widget.platformRepository
          .loadPlatformMediaDefaults();
      if (!mounted) {
        return;
      }
      setState(() {
        _defaults = defaults;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
  }

  Future<void> _uploadImage(PlatformMediaType mediaType) async {
    setState(() => _uploadingType = mediaType);
    try {
      final String? uploadedPath = await widget.platformRepository
          .pickAndUploadPlatformDefaultImage(mediaType: mediaType);
      if (!mounted || uploadedPath == null || uploadedPath.trim().isEmpty) {
        return;
      }
      setState(() {
        _defaults = _applyDraftImage(mediaType, uploadedPath.trim());
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingType = null);
      }
    }
  }

  PlatformMediaDefaults _applyDraftImage(
    PlatformMediaType mediaType,
    String imageUrl,
  ) {
    switch (mediaType) {
      case PlatformMediaType.profile:
        return _defaults.copyWith(profileImageUrl: imageUrl);
      case PlatformMediaType.salon:
        return _defaults.copyWith(salonImageUrl: imageUrl);
      case PlatformMediaType.product:
        return _defaults.copyWith(productImageUrl: imageUrl);
    }
  }

  Future<void> _restoreBuiltIn(PlatformMediaType mediaType) async {
    setState(() {
      _defaults = switch (mediaType) {
        PlatformMediaType.profile => _defaults.copyWith(
          profileImageUrl: defaultProfileImageUrl,
        ),
        PlatformMediaType.salon => _defaults.copyWith(
          salonImageUrl: defaultSalonImageUrl,
        ),
        PlatformMediaType.product => _defaults.copyWith(
          productImageUrl: defaultProductImageUrl,
        ),
      };
    });
  }

  Future<void> _saveDefaults() async {
    setState(() => _isSaving = true);
    try {
      final PlatformMediaDefaults saved = await widget.platformRepository
          .savePlatformMediaDefaults(actor: widget.actor, defaults: _defaults);
      imageCache.clear();
      imageCache.clearLiveImages();
      if (!mounted) {
        return;
      }
      setState(() => _defaults = saved);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Default images updated successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _imageFor(PlatformMediaType mediaType) {
    switch (mediaType) {
      case PlatformMediaType.profile:
        return _defaults.profileImageUrl;
      case PlatformMediaType.salon:
        return _defaults.salonImageUrl;
      case PlatformMediaType.product:
        return _defaults.productImageUrl;
    }
  }

  String _titleFor(PlatformMediaType mediaType) {
    switch (mediaType) {
      case PlatformMediaType.profile:
        return 'Default Profile Image';
      case PlatformMediaType.salon:
        return 'Default Salon Image';
      case PlatformMediaType.product:
        return 'Default Product Image';
    }
  }

  IconData _iconFor(PlatformMediaType mediaType) {
    switch (mediaType) {
      case PlatformMediaType.profile:
        return Icons.person_outline_rounded;
      case PlatformMediaType.salon:
        return Icons.storefront_outlined;
      case PlatformMediaType.product:
        return Icons.inventory_2_outlined;
    }
  }

  Widget _buildImageCard(PlatformMediaType mediaType) {
    final bool isUploading = _uploadingType == mediaType;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _titleFor(mediaType),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: _AppImage(
              imagePath: _imageFor(mediaType),
              height: mediaType == PlatformMediaType.profile ? 140 : 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This image is used whenever the app needs the shared Freshline default for ${mediaType.value}.',
            style: TextStyle(color: AppPalette.mutedForeground, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isUploading ? null : () => _uploadImage(mediaType),
                  icon: isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(_iconFor(mediaType)),
                  label: Text(isUploading ? 'Uploading...' : 'Replace Image'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton(
                  onPressed: isUploading
                      ? null
                      : () => _restoreBuiltIn(mediaType),
                  child: const Text('Restore Built-In'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: const Text('Default Images')),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: appCardDecoration(),
                child: Text(
                  'Update the shared fallback images used by accounts, salons, and products. New defaults are applied from the app without needing code edits.',
                  style: TextStyle(
                    color: AppPalette.mutedForeground,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(minHeight: 3),
                ),
              _buildImageCard(PlatformMediaType.profile),
              const SizedBox(height: 12),
              _buildImageCard(PlatformMediaType.salon),
              const SizedBox(height: 12),
              _buildImageCard(PlatformMediaType.product),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isLoading || _isSaving ? null : _saveDefaults,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Saving...' : 'Save Default Images'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminCouponsScreen extends StatefulWidget {
  const AdminCouponsScreen({
    super.key,
    required this.coupons,
    required this.onSaveCoupon,
  });

  final List<PromoCouponRecord> coupons;
  final Future<PromoCouponRecord> Function(PromoCouponRecord coupon)
  onSaveCoupon;

  @override
  State<AdminCouponsScreen> createState() => _AdminCouponsScreenState();
}

class _AdminCouponsScreenState extends State<AdminCouponsScreen> {
  late final List<PromoCouponRecord> _coupons = List<PromoCouponRecord>.from(
    widget.coupons,
  );
  bool _isSaving = false;

  Future<void> _openEditor([PromoCouponRecord? existing]) async {
    final PromoCouponRecord? draft = await Navigator.of(context)
        .push<PromoCouponRecord>(
          MaterialPageRoute<PromoCouponRecord>(
            builder: (BuildContext context) =>
                AdminCouponEditorScreen(existing: existing),
          ),
        );
    if (draft == null || !mounted) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final PromoCouponRecord saved = await widget.onSaveCoupon(draft);
      if (!mounted) {
        return;
      }
      setState(() {
        final int index = _coupons.indexWhere(
          (PromoCouponRecord item) =>
              item.id == saved.id ||
              item.normalizedCode == saved.normalizedCode,
        );
        if (index >= 0) {
          _coupons[index] = saved;
        } else {
          _coupons.insert(0, saved);
        }
        _coupons.sort((PromoCouponRecord a, PromoCouponRecord b) {
          final DateTime aDate = a.updatedAt ?? a.createdAt ?? DateTime(2000);
          final DateTime bDate = b.updatedAt ?? b.createdAt ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${saved.normalizedCode} saved successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _toggleCoupon(PromoCouponRecord coupon) async {
    setState(() => _isSaving = true);
    try {
      final PromoCouponRecord saved = await widget.onSaveCoupon(
        coupon.copyWith(isActive: !coupon.isActive),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        final int index = _coupons.indexWhere(
          (PromoCouponRecord item) =>
              item.id == saved.id ||
              item.normalizedCode == saved.normalizedCode,
        );
        if (index >= 0) {
          _coupons[index] = saved;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${saved.normalizedCode} saved as ${_statusLabel(saved).toLowerCase()}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatCouponDate(DateTime value) {
    final DateTime local = value.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  String _discountLabel(PromoCouponRecord coupon) {
    final List<String> parts = <String>['${coupon.discountPercent}% off'];
    if (coupon.hasMinimumOrder) {
      parts.add('Min order ${formatBhd(coupon.minOrderAmountBhd!)}');
    }
    if (coupon.hasMaxDiscount) {
      parts.add('Max ${formatBhd(coupon.maxDiscountBhd!)}');
    }
    return parts.join(' · ');
  }

  String _planLabel(PromoCouponRecord coupon) {
    if (coupon.appliesToAllPlans) {
      return 'All users';
    }
    final String planName =
        coupon.targetPlan?.localizedName(context) ?? coupon.targetPlanId ?? '';
    return '$planName plan only';
  }

  String _scheduleLabel(PromoCouponRecord coupon) {
    if (!coupon.hasSchedule) {
      return 'Available immediately until disabled.';
    }
    if (coupon.startsAt != null && coupon.endsAt != null) {
      final int? durationDays = coupon.scheduledDurationDays;
      final String durationLabel = durationDays == null
          ? ''
          : ' · $durationDays day${durationDays == 1 ? '' : 's'}';
      return '${_formatCouponDate(coupon.startsAt!)} to ${_formatCouponDate(coupon.endsAt!)}$durationLabel';
    }
    if (coupon.startsAt != null) {
      return 'Starts on ${_formatCouponDate(coupon.startsAt!)}';
    }
    return 'Ends on ${_formatCouponDate(coupon.endsAt!)}';
  }

  String _statusLabel(PromoCouponRecord coupon) {
    final DateTime now = DateTime.now();
    if (!coupon.isActive) {
      return 'Inactive';
    }
    if (coupon.endsAt != null && now.isAfter(coupon.endsAt!)) {
      return 'Expired';
    }
    if (coupon.startsAt != null && now.isBefore(coupon.startsAt!)) {
      return 'Scheduled';
    }
    return 'Active';
  }

  Color _statusBackground(PromoCouponRecord coupon) {
    switch (_statusLabel(coupon)) {
      case 'Active':
        return AppPalette.success.withValues(alpha: 0.18);
      case 'Scheduled':
        return AppPalette.secondary;
      case 'Expired':
      case 'Inactive':
        return AppPalette.border;
    }
    return AppPalette.border;
  }

  Color _statusForeground(PromoCouponRecord coupon) {
    switch (_statusLabel(coupon)) {
      case 'Active':
        return AppPalette.success;
      case 'Scheduled':
        return AppPalette.primary;
      case 'Expired':
      case 'Inactive':
        return AppPalette.mutedForeground;
    }
    return AppPalette.mutedForeground;
  }

  @override
  Widget build(BuildContext context) {
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Coupon Center'),
          actions: <Widget>[
            IconButton(
              onPressed: _isSaving ? null : () => _openEditor(),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        body: _coupons.isEmpty
            ? Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: _EmptyStateCard(
                  icon: Icons.local_offer_outlined,
                  title: 'No coupons yet',
                  message:
                      'Create the first coupon code for the app, link it to a subscription plan if needed, and set its offer duration.',
                  actionLabel: 'Add Coupon',
                  onAction: _isSaving ? null : () => _openEditor(),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                itemCount: _coupons.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(height: 12),
                itemBuilder: (BuildContext context, int index) {
                  final PromoCouponRecord coupon = _coupons[index];
                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: appCardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    coupon.normalizedCode,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _discountLabel(coupon),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppPalette.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _statusBackground(coupon),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _statusLabel(coupon),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _statusForeground(coupon),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if ((coupon.localizedDescription(context) ?? '')
                            .trim()
                            .isNotEmpty) ...<Widget>[
                          const SizedBox(height: 10),
                          Text(
                            coupon.localizedDescription(context)!.trim(),
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: AppPalette.mutedForeground,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        _AccountInfoRow(
                          label: 'Plan',
                          value: _planLabel(coupon),
                        ),
                        const SizedBox(height: 8),
                        _AccountInfoRow(
                          label: 'Schedule',
                          value: _scheduleLabel(coupon),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isSaving
                                    ? null
                                    : () => _openEditor(coupon),
                                child: const Text('Edit'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: _isSaving
                                    ? null
                                    : () => _toggleCoupon(coupon),
                                child: Text(
                                  coupon.isActive ? 'Disable' : 'Enable',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _isSaving ? null : () => _openEditor(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Coupon'),
        ),
      ),
    );
  }
}

class AdminCouponEditorScreen extends StatefulWidget {
  const AdminCouponEditorScreen({super.key, this.existing});

  final PromoCouponRecord? existing;

  @override
  State<AdminCouponEditorScreen> createState() =>
      _AdminCouponEditorScreenState();
}

class _AdminCouponEditorScreenState extends State<AdminCouponEditorScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _discountController;
  late final TextEditingController _minOrderController;
  late final TextEditingController _maxDiscountController;
  late final TextEditingController _startDateController;
  late final TextEditingController _durationController;
  late DateTime? _startDate;
  late String _targetPlanId;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _startDate = widget.existing?.startsAt?.toLocal();
    _targetPlanId = widget.existing?.targetPlanId ?? '';
    _isActive = widget.existing?.isActive ?? true;
    _codeController = TextEditingController(
      text: widget.existing?.normalizedCode ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.existing?.description ?? '',
    );
    _discountController = TextEditingController(
      text: widget.existing?.discountPercent.toString() ?? '',
    );
    _minOrderController = TextEditingController(
      text: widget.existing?.minOrderAmountBhd?.toStringAsFixed(2) ?? '',
    );
    _maxDiscountController = TextEditingController(
      text: widget.existing?.maxDiscountBhd?.toStringAsFixed(2) ?? '',
    );
    _startDateController = TextEditingController(
      text: _startDate == null ? '' : _formatDate(_startDate!),
    );
    _durationController = TextEditingController(
      text: widget.existing?.scheduledDurationDays?.toString() ?? '',
    );
  }

  String _formatDate(DateTime value) {
    final DateTime local = value.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  double? _parseOptionalAmount(String rawValue) {
    final String text = rawValue.trim();
    if (text.isEmpty) {
      return null;
    }
    final double? parsed = double.tryParse(text);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  int? get _durationDays {
    final String text = _durationController.text.trim();
    if (text.isEmpty) {
      return null;
    }
    final int? parsed = int.tryParse(text);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  DateTime? get _computedEndsAt {
    final int? durationDays = _durationDays;
    if (durationDays == null) {
      return null;
    }
    final DateTime baseDate = _normalizeDate(_startDate ?? DateTime.now());
    return baseDate
        .add(Duration(days: durationDays))
        .subtract(const Duration(seconds: 1));
  }

  Future<void> _pickStartDate() async {
    final DateTime initialDate = _normalizeDate(_startDate ?? DateTime.now());
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _startDate = _normalizeDate(picked);
      _startDateController.text = _formatDate(_startDate!);
    });
  }

  void _clearSchedule() {
    setState(() {
      _startDate = null;
      _startDateController.clear();
      _durationController.clear();
    });
  }

  String _audiencePreview() {
    if (_targetPlanId.trim().isEmpty) {
      return 'All eligible customers can use this offer.';
    }
    final String planName =
        subscriptionPlanById(_targetPlanId)?.name ?? _targetPlanId;
    return 'Only $planName plan customers can use this offer.';
  }

  String _schedulePreview() {
    final DateTime? endsAt = _computedEndsAt;
    if (_startDate == null && endsAt == null) {
      return 'The coupon becomes available immediately and stays active until you disable it.';
    }
    if (_startDate != null && endsAt == null) {
      return 'The coupon starts on ${_formatDate(_startDate!)} and remains active until you disable it.';
    }
    final DateTime startsAt = _normalizeDate(_startDate ?? DateTime.now());
    return 'The offer starts on ${_formatDate(startsAt)} and ends on ${_formatDate(endsAt!)} after ${_durationDays!} day${_durationDays == 1 ? '' : 's'}.';
  }

  @override
  void dispose() {
    _codeController.dispose();
    _descriptionController.dispose();
    _discountController.dispose();
    _minOrderController.dispose();
    _maxDiscountController.dispose();
    _startDateController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final int discountPercent = int.parse(_discountController.text.trim());
    final double? minOrderAmount = _parseOptionalAmount(
      _minOrderController.text,
    );
    final double? maxDiscount = _parseOptionalAmount(
      _maxDiscountController.text,
    );
    final DateTime? startsAt = _startDate == null
        ? (_durationDays == null ? null : _normalizeDate(DateTime.now()))
        : _normalizeDate(_startDate!);
    final DateTime? endsAt = _durationDays == null
        ? null
        : startsAt!
              .add(Duration(days: _durationDays!))
              .subtract(const Duration(seconds: 1));

    Navigator.of(context).pop(
      PromoCouponRecord(
        id: widget.existing?.id,
        code: _codeController.text.trim().toUpperCase(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        discountPercent: discountPercent,
        targetPlanId: _targetPlanId.trim().isEmpty
            ? null
            : _targetPlanId.trim().toLowerCase(),
        minOrderAmountBhd: minOrderAmount,
        maxDiscountBhd: maxDiscount == null || maxDiscount <= 0
            ? null
            : maxDiscount,
        isActive: _isActive,
        startsAt: startsAt,
        endsAt: endsAt,
        createdAt: widget.existing?.createdAt,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool editing = widget.existing != null;
    return AppViewport(
      child: Scaffold(
        appBar: AppBar(title: Text(editing ? 'Edit Coupon' : 'Add Coupon')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: appCardDecoration(),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _AuthTextField(
                    controller: _codeController,
                    label: 'Coupon Code',
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                      LengthLimitingTextInputFormatter(12),
                    ],
                    validator: (String? value) {
                      final String code = (value ?? '').trim();
                      if (code.isEmpty) {
                        return 'Enter a coupon code.';
                      }
                      if (code.length < 3) {
                        return 'Use at least 3 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _AuthTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _AuthTextField(
                          controller: _discountController,
                          label: 'Discount Percent',
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          validator: (String? value) {
                            final int? percent = int.tryParse(
                              (value ?? '').trim(),
                            );
                            if (percent == null) {
                              return 'Enter the discount percent.';
                            }
                            if (percent <= 0 || percent > 100) {
                              return 'Use a value between 1 and 100.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _targetPlanId,
                          decoration: const InputDecoration(
                            labelText: 'Subscription Plan',
                          ),
                          items: <DropdownMenuItem<String>>[
                            const DropdownMenuItem<String>(
                              value: '',
                              child: Text('All Users'),
                            ),
                            ...subscriptionPlans.map(
                              (SubscriptionPlan plan) =>
                                  DropdownMenuItem<String>(
                                    value: plan.id,
                                    child: Text(plan.localizedName(context)),
                                  ),
                            ),
                          ],
                          onChanged: (String? value) {
                            setState(() => _targetPlanId = value ?? '');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _AuthTextField(
                          controller: _minOrderController,
                          label: 'Min Order BHD (Optional)',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          validator: (String? value) {
                            final String text = (value ?? '').trim();
                            if (text.isEmpty) {
                              return null;
                            }
                            final double? amount = double.tryParse(text);
                            if (amount == null || amount <= 0) {
                              return 'Enter a valid min order amount.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _AuthTextField(
                          controller: _maxDiscountController,
                          label: 'Max Discount BHD (Optional)',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          validator: (String? value) {
                            final String text = (value ?? '').trim();
                            if (text.isEmpty) {
                              return null;
                            }
                            final double? maxValue = double.tryParse(text);
                            if (maxValue == null || maxValue <= 0) {
                              return 'Enter a valid max discount value.';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _startDateController,
                    readOnly: true,
                    onTap: _pickStartDate,
                    decoration: InputDecoration(
                      labelText: 'Offer Starts On (Optional)',
                      suffixIcon: IconButton(
                        onPressed: _pickStartDate,
                        icon: const Icon(Icons.calendar_month_rounded),
                      ),
                      filled: true,
                      fillColor: AppPalette.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: AppPalette.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: AppPalette.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: AppPalette.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _AuthTextField(
                    controller: _durationController,
                    label: 'Offer Duration (Days)',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    validator: (String? value) {
                      final String text = (value ?? '').trim();
                      if (text.isEmpty) {
                        return null;
                      }
                      final int? days = int.tryParse(text);
                      if (days == null || days <= 0) {
                        return 'Enter a valid number of days.';
                      }
                      return null;
                    },
                  ),
                  if (_startDate != null ||
                      _durationController.text.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _clearSchedule,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Clear Schedule'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SwitchListTile.adaptive(
                    value: _isActive,
                    onChanged: (bool value) {
                      setState(() => _isActive = value);
                    },
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    subtitle: const Text(
                      'Active offers stay available for eligible customers during their valid dates.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: appCardDecoration(
                      color: AppPalette.background,
                      radius: 22,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Coupon Preview',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _audiencePreview(),
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: AppPalette.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _schedulePreview(),
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: AppPalette.mutedForeground,
                          ),
                        ),
                        if (_minOrderController.text
                            .trim()
                            .isNotEmpty) ...<Widget>[
                          const SizedBox(height: 6),
                          Text(
                            'Minimum order: ${formatBhd(_parseOptionalAmount(_minOrderController.text) ?? 0)}',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: AppPalette.mutedForeground,
                            ),
                          ),
                        ],
                        if (_maxDiscountController.text
                            .trim()
                            .isNotEmpty) ...<Widget>[
                          const SizedBox(height: 6),
                          Text(
                            'Maximum discount: ${formatBhd(_parseOptionalAmount(_maxDiscountController.text) ?? 0)}',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: AppPalette.mutedForeground,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(editing ? 'Save Coupon' : 'Create Coupon'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
