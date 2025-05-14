import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import '../models/event_models.dart';
import '../viewmodels/event_viewmodel.dart';
import '../services/logger_service.dart';
import 'event_detail_view.dart';
import 'create_event_view.dart';

class EventsView extends StatefulWidget {
  final int groupID;
  
  const EventsView({
    Key? key,
    this.groupID = 0,
  }) : super(key: key);

  @override
  _EventsViewState createState() => _EventsViewState();
}

class _EventsViewState extends State<EventsView> {
  final LoggerService _logger = LoggerService();
  bool _isLoading = false;
  CalendarFormat _calendarFormat = CalendarFormat.month; // Varsayılan olarak aylık görünüm
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  late Map<DateTime, List<Event>> _eventsByDay = {};
  int _selectedEventType = 0;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadEvents();
    });
  }
  
  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final eventViewModel = Provider.of<EventViewModel>(context, listen: false);
      if (_selectedEventType == 0) {
        await eventViewModel.loadEvents(groupID: widget.groupID);
      } else if (_selectedEventType == 1) {
        await eventViewModel.loadEvents(groupID: widget.groupID, includeCompanyEvents: false);
      } else if (_selectedEventType == 2) {
        await eventViewModel.loadEvents(groupID: 1);
      }
      _logger.i('Etkinlikler başarıyla yüklendi');
      _organizeEventsByDay();
    } catch (e) {
      _logger.e('Etkinlikler yüklenirken hata: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  void _organizeEventsByDay() {
    _eventsByDay = {};
    final eventViewModel = Provider.of<EventViewModel>(context, listen: false);
    List<Event> events;
    if (_selectedEventType == 0) events = eventViewModel.events;
    else if (_selectedEventType == 1) events = eventViewModel.userEvents;
    else if (_selectedEventType == 2) events = eventViewModel.events;
    else events = [];
    
    for (final event in events) {
      final day = DateTime(
        event.eventDateTime.year,
        event.eventDateTime.month,
        event.eventDateTime.day
      );
      if (_eventsByDay[day] == null) _eventsByDay[day] = [];
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
    
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        padding: const EdgeInsetsDirectional.only(end: 5),
        middle: Text(
          widget.groupID == 0 ? 'Takvim' : 'Grup', 
          style: const TextStyle(fontSize: 16),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.add, size: 22),
          onPressed: () => _navigateToCreateEventView(),
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : Column(
                children: [
                  _EventTypeSelector(
                    selectedType: _selectedEventType,
                    onChanged: (value) {
                      setState(() => _selectedEventType = value);
                      _loadEvents();
                    },
                  ),
                  Expanded(
                    child: eventViewModel.events.isEmpty
                        ? _EmptyEventView(onCreateEvent: _navigateToCreateEventView)
                        : _EventCalendarList(
                            events: eventViewModel.events,
                            eventsByDay: _eventsByDay,
                            focusedDay: _focusedDay,
                            selectedDay: _selectedDay,
                            calendarFormat: _calendarFormat,
                            getEventsForDay: _getEventsForDay,
                            onFormatChanged: (format) => setState(() => _calendarFormat = format),
                            onSelectedDayChanged: (selected, focused) {
                              setState(() {
                                _selectedDay = selected;
                                _focusedDay = focused;
                              });
                            },
                            onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                            onEventTap: _navigateToEventDetail,
                            onCreateEventTap: _navigateToCreateEventView,
                            onDeleteEvent: _showDeleteConfirmation,
                            onEditEvent: _navigateToEditEventView,
                          ),
                  ),
                ],
              ),
      ),
    );
  }
  
  void _navigateToEventDetail(Event event) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => EventDetailPage(
          groupId: widget.groupID,
          eventTitle: event.eventTitle,
          eventDescription: event.eventDesc,
          eventDate: event.eventDateTime.toString(),
          eventUser: event.userFullname,
        ),
      ),
    );
  }
  
  void _navigateToCreateEventView({DateTime? initialDate}) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => CreateEventView(initialDate: initialDate),
      ),
    ).then((result) {
      if (result == true) _loadEvents();
    });
  }
  
  void _navigateToEditEventView(Event event) {
    final eventDate = event.eventDateTime;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => CreateEventView(
          initialDate: eventDate,
          initialGroupID: event.groupID,
          initialTitle: event.eventTitle,
          initialDescription: event.eventDesc,
          isEditing: true,
          eventID: event.eventID,
        ),
      ),
    ).then((result) {
      if (result == true) _loadEvents();
    });
  }
  
  void _showDeleteConfirmation(Event event) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Etkinliği Sil'),
          content: Text('${event.eventTitle} etkinliğini silmek istediğinize emin misiniz?'),
          actions: <Widget>[
            CupertinoDialogAction(
              child: const Text('İptal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteEvent(event);
              },
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _deleteEvent(Event event) async {
    setState(() => _isLoading = true);
    try {
      final eventViewModel = Provider.of<EventViewModel>(context, listen: false);
      final success = await eventViewModel.deleteEvent(event.eventID, groupID: widget.groupID);
      if (success) {
        _loadEvents();
        _showSnackBar('Etkinlik başarıyla silindi.');
      } else {
        _showSnackBar('Etkinlik silinemedi: ${eventViewModel.errorMessage}');
      }
    } catch (e) {
      _logger.e('Etkinlik silinirken hata: $e');
      _showSnackBar('Etkinlik silinirken bir hata oluştu.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _EventTypeSelector extends StatelessWidget {
  final int selectedType;
  final ValueChanged<int> onChanged;

  const _EventTypeSelector({
    Key? key,
    required this.selectedType,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: CupertinoSegmentedControl<int>(
              groupValue: selectedType,
              padding: EdgeInsets.zero,
              children: const {
                0: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Text('Tümü', style: TextStyle(fontSize: 13)),
                ),
                1: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Text('Kişisel', style: TextStyle(fontSize: 13)),
                ),
                2: Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Text('Grup', style: TextStyle(fontSize: 13)),
                ),
              },
              onValueChanged: (value) {
                if (value != null) onChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyEventView extends StatelessWidget {
  final Function({DateTime? initialDate}) onCreateEvent;

  const _EmptyEventView({Key? key, required this.onCreateEvent}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.calendar_badge_minus,
            size: 50,
            color: CupertinoColors.systemGrey,
          ),
          const SizedBox(height: 15),
          const Text(
            'Henüz etkinlik bulunmuyor',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'Yeni etkinlik eklemek için + butonuna dokunun',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 15),
          CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            minSize: 0,
            child: const Text('Etkinlik Ekle', style: TextStyle(fontSize: 14)),
            onPressed: () => onCreateEvent(),
          ),
        ],
      ),
    );
  }
}

class _EventCalendarList extends StatelessWidget {
  final List<Event> events;
  final Map<DateTime, List<Event>> eventsByDay;
  final DateTime focusedDay;
  final DateTime selectedDay;
  final CalendarFormat calendarFormat;
  final List<Event> Function(DateTime) getEventsForDay;
  final Function(CalendarFormat) onFormatChanged;
  final Function(DateTime, DateTime) onSelectedDayChanged;
  final Function(DateTime) onPageChanged;
  final Function(Event) onEventTap;
  final Function({DateTime? initialDate}) onCreateEventTap;
  final Function(Event) onDeleteEvent;
  final Function(Event) onEditEvent;

  const _EventCalendarList({
    Key? key,
    required this.events,
    required this.eventsByDay,
    required this.focusedDay,
    required this.selectedDay,
    required this.calendarFormat,
    required this.getEventsForDay,
    required this.onFormatChanged,
    required this.onSelectedDayChanged,
    required this.onPageChanged,
    required this.onEventTap,
    required this.onCreateEventTap,
    required this.onDeleteEvent,
    required this.onEditEvent,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final eventsForSelectedDay = getEventsForDay(selectedDay);
    
    return Column(
      children: [
        _buildCalendar(context),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat.MMMd('tr_TR').format(selectedDay),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                '${eventsForSelectedDay.length} Etkinlik',
                style: const TextStyle(
                  color: CupertinoColors.secondaryLabel,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: eventsForSelectedDay.isEmpty
              ? _buildEmptyDayView(context)
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: eventsForSelectedDay.length,
                  itemBuilder: (context, index) {
                    return _EventCard(
                      event: eventsForSelectedDay[index],
                      onTap: onEventTap,
                      onDelete: onDeleteEvent,
                      onEdit: onEditEvent,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCalendar(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.separator,
            width: 0.5,
          ),
        ),
      ),
      child: TableCalendar(
        locale: 'tr_TR',
        firstDay: DateTime.utc(2023, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: focusedDay,
        calendarFormat: calendarFormat,
        rowHeight: 45,
        headerStyle: const HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          leftChevronIcon: Icon(
            CupertinoIcons.chevron_left,
            color: CupertinoColors.activeBlue,
            size: 16,
          ),
          rightChevronIcon: Icon(
            CupertinoIcons.chevron_right,
            color: CupertinoColors.activeBlue,
            size: 16,
          ),
          headerMargin: EdgeInsets.only(bottom: 6, top: 6),
          headerPadding: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
        ),
        daysOfWeekHeight: 20,
        calendarStyle: CalendarStyle(
          cellMargin: const EdgeInsets.all(2),
          todayDecoration: const BoxDecoration(
            color: CupertinoColors.activeBlue,
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: CupertinoColors.white,
            border: Border.all(color: CupertinoColors.activeBlue, width: 1.5),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.bold, fontSize: 13),
          selectedTextStyle: const TextStyle(color: CupertinoColors.activeBlue, fontWeight: FontWeight.bold, fontSize: 13),
          defaultTextStyle: const TextStyle(fontSize: 13),
          outsideTextStyle: const TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
          weekendTextStyle: const TextStyle(fontSize: 13, color: Color.fromRGBO(255, 59, 48, 0.7)),
          markersMaxCount: 3,
          markersAlignment: Alignment.bottomCenter,
          markerDecoration: const BoxDecoration(
            color: CupertinoColors.activeOrange,
            shape: BoxShape.circle,
          ),
          markerMargin: const EdgeInsets.only(top: 3),
          markerSize: 4,
          outsideDaysVisible: false,
        ),
        eventLoader: getEventsForDay,
        selectedDayPredicate: (day) => isSameDay(selectedDay, day),
        onDaySelected: onSelectedDayChanged,
        onFormatChanged: onFormatChanged,
        onPageChanged: onPageChanged,
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          weekendStyle: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: Color.fromRGBO(255, 59, 48, 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyDayView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.calendar,
            size: 40,
            color: CupertinoColors.systemGrey,
          ),
          const SizedBox(height: 12),
          const Text(
            'Bu tarihte etkinlik yok',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          CupertinoButton.filled(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            minSize: 0,
            child: const Text('Etkinlik Ekle', style: TextStyle(fontSize: 13)),
            onPressed: () => onCreateEventTap(initialDate: selectedDay),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final Function(Event) onTap;
  final Function(Event) onDelete;
  final Function(Event)? onEdit;

  const _EventCard({
    Key? key,
    required this.event,
    required this.onTap,
    required this.onDelete,
    this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final eventDate = event.eventDateTime;
    final isUpcoming = eventDate.isAfter(now);
    final isCompanyEvent = event.eventType == 'company';
    
    Color statusColor;
    String statusText;
    
    if (isUpcoming) {
      if (eventDate.difference(now).inDays < 3) {
        statusColor = CupertinoColors.systemOrange;
        statusText = 'Yakında';
      } else {
        statusColor = CupertinoColors.activeGreen;
        statusText = 'Planlandı';
      }
    } else {
      statusColor = CupertinoColors.systemGrey;
      statusText = 'Geçmiş';
    }
    
    final eventTime = DateFormat('HH:mm').format(eventDate);
    
    return GestureDetector(
      onTap: () => onTap(event),
      child: Dismissible(
        key: Key('event_${event.eventID}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: CupertinoColors.destructiveRed,
          child: const Icon(
            CupertinoIcons.delete,
            color: CupertinoColors.white,
          ),
        ),
        confirmDismiss: (direction) async {
          onDelete(event);
          return false; // İletişim kutusu ile onay alacağız
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.systemGrey5.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
            border: isCompanyEvent ? Border.all(
              color: CupertinoColors.activeBlue.withOpacity(0.3),
              width: 1,
            ) : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: isCompanyEvent 
                                ? CupertinoColors.activeBlue.withOpacity(0.1)
                                : statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                eventTime,
                                style: TextStyle(
                                  color: isCompanyEvent 
                                      ? CupertinoColors.activeBlue
                                      : statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isCompanyEvent 
                                      ? CupertinoColors.activeBlue
                                      : statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
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
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                event.eventDesc,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: CupertinoColors.label,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(
                                    isCompanyEvent
                                        ? CupertinoIcons.briefcase
                                        : CupertinoIcons.person,
                                    size: 12,
                                    color: CupertinoColors.secondaryLabel,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      isCompanyEvent ? 'Şirket Etkinliği' : event.userFullname,
                                      style: const TextStyle(
                                        color: CupertinoColors.secondaryLabel,
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      CupertinoButton(
                                        padding: EdgeInsets.zero,
                                        minSize: 0,
                                        child: const Icon(
                                          CupertinoIcons.delete,
                                          size: 18,
                                          color: CupertinoColors.systemRed,
                                        ),
                                        onPressed: () => onDelete(event),
                                      ),
                                      const SizedBox(width: 8),
                                      CupertinoButton(
                                        padding: EdgeInsets.zero,
                                        minSize: 0,
                                        child: const Icon(
                                          CupertinoIcons.pencil,
                                          size: 18,
                                          color: CupertinoColors.activeBlue,
                                        ),
                                        onPressed: () => onEdit != null ? onEdit!(event) : null,
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: CupertinoColors.systemGrey6,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          CupertinoIcons.chevron_right,
                                          size: 10,
                                          color: CupertinoColors.systemGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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