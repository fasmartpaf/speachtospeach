enum AppState {
  idle,
  listening,
  processing,
  speaking,
  error,
}

class ConversationState {
  final String? userMessage;
  final String? aiResponse;
  final AppState currentState;
  final String? errorMessage;

  ConversationState({
    this.userMessage,
    this.aiResponse,
    this.currentState = AppState.idle,
    this.errorMessage,
  });

  ConversationState copyWith({
    String? userMessage,
    String? aiResponse,
    AppState? currentState,
    String? errorMessage,
  }) {
    return ConversationState(
      userMessage: userMessage ?? this.userMessage,
      aiResponse: aiResponse ?? this.aiResponse,
      currentState: currentState ?? this.currentState,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
