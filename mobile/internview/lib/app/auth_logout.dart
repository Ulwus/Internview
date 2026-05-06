/// [AuthInterceptor] Riverpod dışında olduğu için yenileme başarısızında oturumu buradan temizler.
void Function()? _onAuthLogout;

void bindAuthLogout(void Function() fn) {
  _onAuthLogout = fn;
}

void fireAuthLogout() {
  _onAuthLogout?.call();
}
