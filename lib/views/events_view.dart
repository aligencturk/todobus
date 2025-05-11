import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_platform_widgets/flutter_platform_widgets.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/event_models.dart';
import '../viewmodels/event_viewmodel.dart';
import '../services/logger_service.dart';
import 'event_detail_view.dart';
import 'create_event_view.dart';

class EventsView extends StatefulWidget {
  final int groupID;
  
  const EventsView({
    Key? key,
    this.groupID = 0, // 0 ise kullanıcının tüm etkinlikleri
  }) : super(key: key);

  @override
  _EventsViewState createState() => _EventsViewState();
}

class _EventsViewState extends State<EventsView> {
  final LoggerService _logger = LoggerService();
  bool _isLoading = false;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  int _calendarHeaderHeight = 80;
  late Map<DateTime, List<Event>> _eventsByDay;
  int _selectedEventType = 0; // 0: Tüm etkinlikler, 1: Kullanıcı etkinlikleri, 2: Şirket etkinlikleri
  
  @override
  void initState() {
    super.initState();
    
    // Sayfa açıldığında verileri yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadEvents();
      }
    });
  }
  
  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final eventViewModel = Provider.of<EventViewModel>(context, listen: false);
      
      if (_selectedEventType == 0) {
        // Tüm etkinlikleri yükle
        await eventViewModel.loadEvents(groupID: widget.groupID);
      } else if (_selectedEventType == 1) {
        // Sadece kullanıcı etkinliklerini yükle
        await eventViewModel.loadEvents(groupID: widget.groupID, includeCompanyEvents: false);
      } else {
        // Sadece şirket etkinliklerini yükle
        await eventViewModel.loadCompanyEventsOnly();
      }
      
      _logger.i('Etkinlikler başarıyla yüklendi');
      _organizeEventsByDay();
    } catch (e) {
      _logger.e('Etkinlikler yüklenirken hata: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _organizeEventsByDay() {
    _eventsByDay = {};
    final eventViewModel = Provider.of<EventViewModel>(context, listen: false);
    List<Event> events;
    
    if (_selectedEventType == 0) {
      events = eventViewModel.events;
    } else if (_selectedEventType == 1) {
      events = eventViewModel.userEvents;
    } else {
      events = eventViewModel.companyEvents;
    }
    
    for (final event in events) {
      final eventDate = event.eventDateTime;
      final day = DateTime(eventDate.year, eventDate.month, eventDate.day);
      
      if (_eventsByDay[day] == null) {
        _eventsByDay[day] = [];
      }
      
      _eventsByDay[day]!.add(event);
    }
  }
  
  List<Event> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    return _eventsByDay[normalizedDay] ?? [];
  }
  
  @override
  Widget build(BuildContext context) {
    final eventViewModel = Provider.of<EventViewModel>(context);
    final isIOS = isCupertino(context);
    
    return PlatformScaffold(
      appBar: PlatformAppBar(
        title: Text(widget.groupID == 0 ? 'Takvim' : 'Grup Etkinlikleri'),
        trailingActions: <Widget>[
          PlatformIconButton(
            icon: Icon(isIOS ? CupertinoIcons.add : Icons.add),
            onPressed: () => _navigateToCreateEventView(),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: PlatformCircularProgressIndicator(),
              )
            : Column(
                children: [
                  _buildEventTypeSelector(context),
                  Expanded(
                    child: eventViewModel.events.isEmpty
                        ? _buildEmptyState(context)
                        : _buildCalendarWithEvents(context, eventViewModel.events),
                  ),
                ],
              ),
      ),
    );
  }
  
  Widget _buildEmptyState(BuildContext context) {
    final isIOS = isCupertino(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isIOS ? CupertinoIcons.calendar_badge_minus : Icons.event_busy,
            size: 72,
            color: isIOS ? CupertinoColors.systemGrey : Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz etkinlik bulunmuyor',
            style: platformThemeData(
              context,
              material: (data) => data.textTheme.titleLarge,
              cupertino: (data) => data.textTheme.navTitleTextStyle,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Yeni bir etkinlik eklemek için + butonuna tıklayın',
            style: platformThemeData(
              context,
              material: (data) => data.textTheme.bodyMedium?.copyWith(color: Colors.grey),
              cupertino: (data) => data.textTheme.textStyle.copyWith(
                color: CupertinoColors.secondaryLabel,
              ),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          PlatformElevatedButton(
            onPressed: () => _navigateToCreateEventView(),
            child: Text('Yeni Etkinlik Ekle'),
            material: (_, __) => MaterialElevatedButtonData(
              icon: const Icon(Icons.add),
            ),
            cupertino: (_, __) => CupertinoElevatedButtonData(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEventTypeSelector(BuildContext context) {
    final isIOS = isCupertino(context);
    
    if (isIOS) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          border: Border(
            bottom: BorderSide(
              color: CupertinoColors.separator,
              width: 0.5,
            ),
          ),
        ),
        child: CupertinoSlidingSegmentedControl<int>(
          groupValue: _selectedEventType,
          children: const {
            0: Text('Tümü'),
            1: Text('Kişisel'),
            2: Text('Şirket'),
          },
          onValueChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedEventType = value;
              });
              _loadEvents();
            }
          },
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: SegmentedButton<int>(
          segments: const [
            ButtonSegment<int>(
              value: 0,
              label: Text('Tümü'),
            ),
            ButtonSegment<int>(
              value: 1,
              label: Text('Kişisel'),
            ),
            ButtonSegment<int>(
              value: 2,
              label: Text('Şirket'),
            ),
          ],
          selected: {_selectedEventType},
          onSelectionChanged: (Set<int> newSelection) {
            setState(() {
              _selectedEventType = newSelection.first;
            });
            _loadEvents();
          },
        ),
      );
    }
  }
  
  Widget _buildCalendarWithEvents(BuildContext context, List<Event> allEvents) {
    final isIOS = isCupertino(context);
    final eventsForSelectedDay = _getEventsForDay(_selectedDay);
    
    return Column(
      children: [
        _buildCalendar(context),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat.yMMMd('tr_TR').format(_selectedDay),
                style: platformThemeData(
                  context,
                  material: (data) => data.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  cupertino: (data) => data.textTheme.navTitleTextStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ),
              Text(
                '${eventsForSelectedDay.length} Etkinlik',
                style: platformThemeData(
                  context,
                  material: (data) => data.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  cupertino: (data) => data.textTheme.textStyle.copyWith(
                    color: CupertinoColors.secondaryLabel,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: eventsForSelectedDay.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isIOS ? CupertinoIcons.calendar : Icons.event_available,
                        size: 48,
                        color: isIOS ? CupertinoColors.systemGrey : Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Bu tarihte etkinlik yok',
                        style: platformThemeData(
                          context,
                          material: (data) => data.textTheme.titleMedium,
                          cupertino: (data) => data.textTheme.navTitleTextStyle.copyWith(fontSize: 16),
                        ),
                      ),
                      const SizedBox(height: 8),
                      PlatformElevatedButton(
                        onPressed: () => _navigateToCreateEventView(initialDate: _selectedDay),
                        child: Text('Bu Güne Etkinlik Ekle'),
                        cupertino: (_, __) => CupertinoElevatedButtonData(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: eventsForSelectedDay.length,
                  itemBuilder: (context, index) {
                    return _buildEventItem(context, eventsForSelectedDay[index]);
                  },
                ),
        ),
      ],
    );
  }
  
  Widget _buildCalendar(BuildContext context) {
    final isIOS = isCupertino(context);
    
    return Container(
      decoration: BoxDecoration(
        color: isIOS ? CupertinoColors.systemBackground : Colors.white,
        boxShadow: [
          BoxShadow(
            color: isIOS ? CupertinoColors.systemGrey6 : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TableCalendar(
        locale: 'tr_TR',
        firstDay: DateTime.utc(2023, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        headerStyle: HeaderStyle(
          titleCentered: true,
          formatButtonVisible: !isIOS,
          titleTextStyle: isIOS
              ? CupertinoTheme.of(context).textTheme.navTitleTextStyle.copyWith(fontSize: 17)
              : const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          leftChevronIcon: Icon(
            isIOS ? CupertinoIcons.chevron_left : Icons.chevron_left,
            color: isIOS ? CupertinoColors.activeBlue : Theme.of(context).primaryColor,
          ),
          rightChevronIcon: Icon(
            isIOS ? CupertinoIcons.chevron_right : Icons.chevron_right,
            color: isIOS ? CupertinoColors.activeBlue : Theme.of(context).primaryColor,
          ),
          headerMargin: EdgeInsets.only(bottom: 8, top: isIOS ? 8 : 16),
          headerPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: isIOS ? CupertinoColors.systemBackground : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isIOS ? CupertinoColors.separator : Colors.grey.withOpacity(0.2),
                width: 0.5,
              ),
            ),
          ),
        ),
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: isIOS ? CupertinoColors.activeBlue.withOpacity(0.1) : Theme.of(context).primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: isIOS ? CupertinoColors.activeBlue : Theme.of(context).primaryColor,
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: isIOS ? CupertinoColors.activeBlue : Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
          ),
          selectedTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          markersMaxCount: 3,
          markersAlignment: Alignment.bottomCenter,
          markerDecoration: BoxDecoration(
            color: isIOS ? CupertinoColors.activeOrange : Colors.orange,
            shape: BoxShape.circle,
          ),
          markerMargin: const EdgeInsets.only(top: 4),
          markerSize: 6,
          outsideDaysVisible: false,
        ),
        eventLoader: _getEventsForDay,
        selectedDayPredicate: (day) {
          return isSameDay(_selectedDay, day);
        },
        availableCalendarFormats: const {
          CalendarFormat.month: 'Ay',
          CalendarFormat.twoWeeks: '2 Hafta',
          CalendarFormat.week: 'Hafta',
        },
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onFormatChanged: (format) {
          setState(() {
            _calendarFormat = format;
          });
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
      ),
    );
  }
  
  Widget _buildEventItem(BuildContext context, Event event) {
    final isIOS = isCupertino(context);
    final now = DateTime.now();
    final eventDate = event.eventDateTime;
    final isUpcoming = eventDate.isAfter(now);
    final isCompanyEvent = event.eventType == 'company';
    
    // Tarih durumunu belirle
    Color statusColor;
    String statusText;
    
    if (isUpcoming) {
      if (eventDate.difference(now).inDays < 3) {
        statusColor = isIOS ? CupertinoColors.systemOrange : Colors.orange;
        statusText = 'Yaklaşıyor';
      } else {
        statusColor = isIOS ? CupertinoColors.activeGreen : Colors.green;
        statusText = 'Planlandı';
      }
    } else {
      statusColor = isIOS ? CupertinoColors.systemGrey : Colors.grey;
      statusText = 'Süresi Doldu';
    }
    
    final eventTimeFormat = DateFormat('HH:mm');
    final eventTime = eventTimeFormat.format(eventDate);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isIOS ? CupertinoColors.systemBackground : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isIOS ? CupertinoColors.systemGrey5.withOpacity(0.4) : Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: isCompanyEvent ? Border.all(
          color: isIOS ? CupertinoColors.activeBlue.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
          width: 1.5,
        ) : null,
      ),
      child: PlatformWidget(
        material: (_, __) => InkWell(
          onTap: () => _navigateToEventDetail(event),
          borderRadius: BorderRadius.circular(12),
          child: _buildEventItemContent(context, event, eventTime, statusColor, statusText, isCompanyEvent),
        ),
        cupertino: (_, __) => GestureDetector(
          onTap: () => _navigateToEventDetail(event),
          child: _buildEventItemContent(context, event, eventTime, statusColor, statusText, isCompanyEvent),
        ),
      ),
    );
  }
  
  Widget _buildEventItemContent(BuildContext context, Event event, String eventTime, Color statusColor, String statusText, bool isCompanyEvent) {
    final isIOS = isCupertino(context);
    
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isCompanyEvent 
                  ? (isIOS ? CupertinoColors.activeBlue.withOpacity(0.1) : Colors.blue.withOpacity(0.1))
                  : statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              eventTime,
              style: TextStyle(
                color: isCompanyEvent 
                    ? (isIOS ? CupertinoColors.activeBlue : Colors.blue)
                    : statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.eventTitle,
                        style: platformThemeData(
                          context,
                          material: (data) => data.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          cupertino: (data) => data.textTheme.navTitleTextStyle.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCompanyEvent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: isIOS ? CupertinoColors.activeBlue.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Şirket',
                          style: TextStyle(
                            color: isIOS ? CupertinoColors.activeBlue : Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  event.eventDesc,
                  style: platformThemeData(
                    context,
                    material: (data) => data.textTheme.bodyMedium,
                    cupertino: (data) => data.textTheme.textStyle.copyWith(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCompanyEvent
                              ? (isIOS ? CupertinoIcons.briefcase : Icons.business)
                              : (isIOS ? CupertinoIcons.person : Icons.person),
                          size: 14,
                          color: isIOS ? CupertinoColors.secondaryLabel : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isCompanyEvent ? 'Şirket Etkinliği' : event.userFullname,
                          style: platformThemeData(
                            context,
                            material: (data) => data.textTheme.labelSmall,
                            cupertino: (data) => data.textTheme.actionTextStyle.copyWith(
                              color: CupertinoColors.secondaryLabel,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Icon(
                      isIOS ? CupertinoIcons.chevron_right : Icons.arrow_forward_ios,
                      size: 14,
                      color: isIOS ? CupertinoColors.systemGrey : Colors.grey,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  void _navigateToEventDetail(Event event) {
    Navigator.of(context).push(
      platformPageRoute(
        context: context,
        builder: (context) => EventDetailView(eventID: event.eventID),
      ),
    );
  }
  
  void _navigateToCreateEventView({DateTime? initialDate}) {
    Navigator.of(context).push(
      platformPageRoute(
        context: context,
        builder: (context) => CreateEventView(
          initialDate: initialDate,
        ),
      ),
    ).then((result) {
      // Eğer yeni etkinlik oluşturuldu ise, etkinlikleri yeniden yükle
      if (result == true) {
        _loadEvents();
      }
    });
  }
} 