#pragma once
#include <QObject>

class UIValidator : public QObject {
    Q_OBJECT
public:
    explicit UIValidator(QObject* parent = nullptr);

    Q_INVOKABLE int availableDisplayCount() const;
    Q_INVOKABLE bool verifyDisplayCount(int required) const;
};
