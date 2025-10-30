#pragma once

#include "backend/computermanager.h"
#include "streaming/session.h"

#include <QAbstractListModel>
#include <QHash>
#include <QVector>
#include <QVariant>

class ComputerModel : public QAbstractListModel
{
    Q_OBJECT
public:
    enum Roles {
        NameRole = Qt::UserRole + 1,
        OnlineRole,
        PairedRole,
        BusyRole,
        WakeableRole,
        StatusUnknownRole,
        ServerSupportedRole,
        DetailsRole,

        // Grouping + multi-display
        IpRole,
        IsPrimaryRole,
        DisplayCountRole,
        DisplayNamesRole,
    };
    Q_ENUM(Roles)

public:
    explicit ComputerModel(QObject* object = nullptr);

    // Must be called before use
    Q_INVOKABLE void initialize(ComputerManager* computerManager);

    // QAbstractListModel
    QVariant data(const QModelIndex &index, int role) const override;
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QHash<int, QByteArray> roleNames() const override;

    // Management
    Q_INVOKABLE void deleteComputer(int computerIndex);
    Q_INVOKABLE QString generatePinString();
    Q_INVOKABLE void pairComputer(int computerIndex, QString pin);
    Q_INVOKABLE void testConnectionForComputer(int computerIndex);
    Q_INVOKABLE void wakeComputer(int computerIndex);
    Q_INVOKABLE void renameComputer(int computerIndex, QString name);

    Q_INVOKABLE int  groupDisplayCount(int row) const;

    // Launch one display of a computer via CLI (detached process)
    Q_INVOKABLE bool launchDisplayViaCli(int computerIndex, int displayIndex);

    // Launch all displays for a computer via CLI (returns number started)
    Q_INVOKABLE int launchAllDisplaysViaCli(int computerIndex);

signals:
    void pairingCompleted(QVariant error);
    void connectionTestCompleted(int result, QString blockedPorts);

private slots:
    void handleComputerStateChanged(NvComputer* computer);
    void handlePairingCompleted(NvComputer* computer, QString error);

private:
    // Helpers for grouping by IP (computed on the fly)
    QString ipOfRow(int row) const;
    int firstRowForIp(const QString& ip) const;                 // primary row
    int countRowsForIp(const QString& ip) const;                 // number of peers
    QVector<int> rowsForIp(const QString& ip) const;             // all member rows
    int rowForIpAndDisplayIndex(const QString& ip, int displayIndex) const; // N-th peer
    QVector<int> groupMembersForRow(int row) const;

private:
    QVector<NvComputer*> m_Computers;
    ComputerManager*     m_ComputerManager = nullptr;
};
