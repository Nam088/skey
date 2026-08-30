#include "MainWindow.xaml.h"

#ifdef _WIN32
namespace winrt::SKey::Settings::implementation {
void MainWindow::NavigateForTag(winrt::hstring const&) {}
}
#endif
