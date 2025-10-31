#include "uivalidator.h"
#include <QGuiApplication>
#include <QScreen>

UIValidator::UIValidator(QObject* parent) : QObject(parent) {}

int UIValidator::availableDisplayCount() const {
    return QGuiApplication::screens().size();
}

bool UIValidator::verifyDisplayCount(int required) const {
    return required <= availableDisplayCount();
}
