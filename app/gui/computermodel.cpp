#include "computermodel.h"

#include <algorithm>
#include <QThreadPool>
#include <QMetaObject>
#include <QReadLocker>
#include <QVariant>
#include <QCoreApplication>
#include <QProcess>
#include <QDebug>

// ===== ctor / init =====
ComputerModel::ComputerModel(QObject* object)
    : QAbstractListModel(object) {}

void ComputerModel::initialize(ComputerManager* computerManager)
{
    m_ComputerManager = computerManager;
    connect(m_ComputerManager, &ComputerManager::computerStateChanged,
            this, &ComputerModel::handleComputerStateChanged);
    connect(m_ComputerManager, &ComputerManager::pairingCompleted,
            this, &ComputerModel::handlePairingCompleted);

    m_Computers = m_ComputerManager->getComputers();
}

// ===== grouping helpers (by IP) =====
QString ComputerModel::ipOfRow(int row) const
{
    if (row < 0 || row >= m_Computers.size()) return {};
    const NvComputer* c = m_Computers[row];
    QReadLocker lock(&c->lock);
    return c->activeAddress.address();
}

int ComputerModel::firstRowForIp(const QString& ip) const
{
    if (ip.isEmpty()) return -1;
    for (int i = 0; i < m_Computers.size(); ++i) {
        const NvComputer* c = m_Computers[i];
        QReadLocker lock(&c->lock);
        if (c->activeAddress.address() == ip) return i;
    }
    return -1;
}

int ComputerModel::countRowsForIp(const QString& ip) const
{
    if (ip.isEmpty()) return 0;
    int n = 0;
    for (int i = 0; i < m_Computers.size(); ++i) {
        const NvComputer* c = m_Computers[i];
        QReadLocker lock(&c->lock);
        if (c->activeAddress.address() == ip) ++n;
    }
    return n;
}

QVector<int> ComputerModel::rowsForIp(const QString& ip) const
{
    QVector<int> out;
    if (ip.isEmpty()) return out;
    for (int i = 0; i < m_Computers.size(); ++i) {
        const NvComputer* c = m_Computers[i];
        QReadLocker lock(&c->lock);
        if (c->activeAddress.address() == ip) out.push_back(i);
    }
    return out;
}


// ===== model roles =====
QVariant ComputerModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid()) return QVariant();
    const int row = index.row();
    if (row < 0 || row >= m_Computers.count()) return QVariant();

    NvComputer* computer = m_Computers[row];
    QReadLocker lock(&computer->lock);

    const QString ip = computer->activeAddress.address();

    switch (role) {
    case NameRole:
        return computer->name;
    case OnlineRole:
        return computer->state == NvComputer::CS_ONLINE;
    case PairedRole:
        return computer->pairState == NvComputer::PS_PAIRED;
    case BusyRole:
        return computer->currentGameId != 0;
    case WakeableRole:
        return !computer->macAddress.isEmpty();
    case StatusUnknownRole:
        return computer->state == NvComputer::CS_UNKNOWN;
    case ServerSupportedRole:
        return computer->isSupportedServerVersion;

    case DetailsRole: {
        QString state, pairState;
        switch (computer->state) {
        case NvComputer::CS_ONLINE:  state = tr("Online");  break;
        case NvComputer::CS_OFFLINE: state = tr("Offline"); break;
        default:                     state = tr("Unknown"); break;
        }
        switch (computer->pairState) {
        case NvComputer::PS_PAIRED:      pairState = tr("Paired");   break;
        case NvComputer::PS_NOT_PAIRED:  pairState = tr("Unpaired"); break;
        default:                         pairState = tr("Unknown");  break;
        }

        return tr("Name: %1").arg(computer->name) + '\n' +
               tr("Status: %1").arg(state) + '\n' +
               tr("Active Address: %1").arg(computer->activeAddress.toString()) + '\n' +
               tr("UUID: %1").arg(computer->uuid) + '\n' +
               tr("Local Address: %1").arg(computer->localAddress.toString()) + '\n' +
               tr("Remote Address: %1").arg(computer->remoteAddress.toString()) + '\n' +
               tr("IPv6 Address: %1").arg(computer->ipv6Address.toString()) + '\n' +
               tr("Manual Address: %1").arg(computer->manualAddress.toString()) + '\n' +
               tr("MAC Address: %1").arg(computer->macAddress.isEmpty() ? tr("Unknown")
                                                                        : QString(computer->macAddress.toHex(':'))) + '\n' +
               tr("Pair State: %1").arg(pairState) + '\n' +
               tr("Running Game ID: %1").arg(computer->state == NvComputer::CS_ONLINE
                                                 ? QString::number(computer->currentGameId) : tr("Unknown")) + '\n' +
               tr("HTTPS Port: %1").arg(computer->state == NvComputer::CS_ONLINE
                                            ? QString::number(computer->activeHttpsPort) : tr("Unknown"));
    }

    case IpRole:
        return ip;

    case IsPrimaryRole: {
        // Only the first row for a given IP is primary
        const int first = firstRowForIp(ip);
        return first == row;
    }

    case DisplayCountRole: {
        // Count rows sharing this IP
        return countRowsForIp(ip);
    }

    case DisplayNamesRole: {
        // Build names across all rows with this IP: "Name (:port)"
        QVariantList lst;
        const auto rows = rowsForIp(ip);
        lst.reserve(rows.size());
        for (int r : rows) {
            NvComputer* peer = m_Computers[r];
            QReadLocker plock(&peer->lock);
            lst << QString("%1 (:%2)").arg(peer->name).arg(peer->activeHttpsPort);
        }
        return lst;
    }

    default:
        return QVariant();
    }
}

int ComputerModel::rowCount(const QModelIndex& parent) const
{
    if (parent.isValid()) return 0;
    return m_Computers.count();
}

QHash<int, QByteArray> ComputerModel::roleNames() const
{
    QHash<int, QByteArray> names;
    names[NameRole]            = "name";
    names[OnlineRole]          = "online";
    names[PairedRole]          = "paired";
    names[BusyRole]            = "busy";
    names[WakeableRole]        = "wakeable";
    names[StatusUnknownRole]   = "statusUnknown";
    names[ServerSupportedRole] = "serverSupported";
    names[DetailsRole]         = "details";

    names[IpRole]              = "ip";
    names[IsPrimaryRole]       = "isPrimary";
    names[DisplayCountRole]    = "displayCount";
    names[DisplayNamesRole]    = "displayNames";
    return names;
}

// ===== Launch Via Detatched cli ====
static QString chooseAppNameFor(NvComputer* c)
{
    // Prefer the currently running app by ID (if any)
    if (c->currentGameId != 0) {
        for (const NvApp& app : c->appList) {
            if (app.id == c->currentGameId) {
                return app.name;
            }
        }
    }

    // Fall back to first app in list (typically "Desktop")
    if (!c->appList.isEmpty()) {
        return c->appList.first().name;
    }

    // Final fallback
    return QStringLiteral("Desktop");
}

static bool hostHasExplicitPort(const QString& host)
{
    if (host.startsWith('[')) {
        // Bracketed IPv6 form: look for "]:<digits>" at the end
        int pos = host.indexOf("]:");
        if (pos == -1) return false;
        const QString after = host.mid(pos + 2);
        if (after.isEmpty()) return false;
        for (QChar ch : after) if (!ch.isDigit()) return false;
        return true;
    }

    // Non-bracketed form:
    // Treat as having a port only if the final ":" is followed by all digits.
    int lastColon = host.lastIndexOf(':');
    if (lastColon < 0) return false;
    const QString after = host.mid(lastColon + 1);
    if (after.isEmpty()) return false;
    for (QChar ch : after) if (!ch.isDigit()) return false;
    return true;
}

static QString withPort(const QString& host, int port)
{
    if (hostHasExplicitPort(host)) {
        return host;
    }

    // If it contains ':' but isn't bracketed, assume it's a raw IPv6 literal.
    if (host.contains(':') && !host.startsWith('[')) {
        return QStringLiteral("[%1]:%2").arg(host).arg(port);
    }

    // IPv4 or hostname without port.
    return QStringLiteral("%1:%2").arg(host).arg(port);
}

QString ComputerModel::webUIURL(int row) const
{
    NvComputer* c = m_Computers[row];

    const QString baseHost = c->activeAddress.address();
    const QString host = withPort(baseHost, c->activeAddress.port() + 1);
    return QStringLiteral("%1%2").arg("https://").arg(host);
}

bool ComputerModel::launchDisplayViaCli(int computerIndex, int displayIndex)
{
    if (computerIndex < 0 || computerIndex >= m_Computers.size()) {
        qWarning() << "launchDisplayViaCli: invalid computerIndex" << computerIndex;
        return false;
    }

    NvComputer* c = m_Computers[computerIndex];
    QReadLocker lock(&c->lock);

    // Positional args expected by your StreamCommandLineParser:
    //   0: --stream      (or whatever your global parser expects to select StreamRequested)
    //   1: host          (IP or name)
    //   2: appName       (picked below)
    //   3: displayId     (uint)
    const QString exe = QCoreApplication::applicationFilePath();
    const QString baseHost = c->activeAddress.address();
    const QString host = withPort(baseHost, c->activeAddress.port());
    const QString appName = chooseAppNameFor(c);
    const uint displayId = displayIndex;

    QStringList args;
    args << QStringLiteral("stream")
         << host
         << appName
         << QString::number(displayId)
         << QStringLiteral("--video-codec") << QStringLiteral("HEVC")
         << QStringLiteral("--video-decoder") << QStringLiteral("hardware")
         << QStringLiteral("--capture-system-keys") << QStringLiteral("always")
         << QStringLiteral("--vsync");

    bool ok = QProcess::startDetached(exe, args);
    if (!ok) {
        qWarning() << "Failed to start detached stream process for" << c->name
                   << "display" << displayIndex << "args:" << args;
    } else {
        qDebug() << "Started stream process:" << exe << args;
    }
    return ok;
}

QVector<int> ComputerModel::groupMembersForRow(int row) const
{
    QVector<int> out;
    if (row < 0 || row >= m_Computers.size()) return out;

    const NvComputer* base = m_Computers[row];
    const QString ip = base->activeAddress.address();

    // Collect all rows with the same IP
    for (int i = 0; i < m_Computers.size(); ++i) {
        const NvComputer* c = m_Computers[i];
        if (c->activeAddress.address() == ip) {
            out.push_back(i);
        }
    }

    // Stable order: by activeHttpsPort, then by name as tiebreaker
    std::sort(out.begin(), out.end(), [&](int a, int b) {
        const NvComputer* ca = m_Computers[a];
        const NvComputer* cb = m_Computers[b];
        if (ca->activeHttpsPort != cb->activeHttpsPort)
            return ca->activeHttpsPort < cb->activeHttpsPort;
        return ca->name < cb->name;
    });

    return out;
}

int ComputerModel::groupDisplayCount(int row) const
{
    return groupMembersForRow(row).size();
}

int ComputerModel::launchAllDisplaysViaCli(int row)
{
    const QVector<int> members = groupMembersForRow(row);
    if (members.isEmpty()) return 0;

    int launched = 0;
    for (int r : members) {
        if (launchDisplayViaCli(r, launched)) {
            ++launched;
        }
    }
    return launched;
}

// ===== management actions =====
void ComputerModel::deleteComputer(int computerIndex)
{
    Q_ASSERT(computerIndex >= 0 && computerIndex < m_Computers.count());

    beginRemoveRows(QModelIndex(), computerIndex, computerIndex);

    m_ComputerManager->deleteHost(m_Computers[computerIndex]);
    m_Computers.removeAt(computerIndex);

    endRemoveRows();
}

class DeferredWakeHostTask : public QRunnable
{
public:
    explicit DeferredWakeHostTask(NvComputer* computer) : m_Computer(computer) {}
    void run() override { m_Computer->wake(); }
private:
    NvComputer* m_Computer;
};

void ComputerModel::wakeComputer(int computerIndex)
{
    Q_ASSERT(computerIndex >= 0 && computerIndex < m_Computers.count());
    auto* task = new DeferredWakeHostTask(m_Computers[computerIndex]);
    QThreadPool::globalInstance()->start(task);
}

void ComputerModel::renameComputer(int computerIndex, QString name)
{
    Q_ASSERT(computerIndex >= 0 && computerIndex < m_Computers.count());
    m_ComputerManager->renameHost(m_Computers[computerIndex], std::move(name));
}

QString ComputerModel::generatePinString()
{
    return m_ComputerManager->generatePinString();
}

class DeferredTestConnectionTask : public QObject, public QRunnable
{
    Q_OBJECT
public:
    void run() override
    {
        unsigned int portTestResult = LiTestClientConnectivity("qt.conntest.moonlight-stream.org", 443, ML_PORT_FLAG_ALL);
        if (portTestResult == ML_TEST_RESULT_INCONCLUSIVE) {
            emit connectionTestCompleted(-1, QString());
        } else {
            char blockedPorts[512];
            LiStringifyPortFlags(portTestResult, "\n", blockedPorts, sizeof(blockedPorts));
            emit connectionTestCompleted(static_cast<int>(portTestResult), QString(blockedPorts));
        }
    }
signals:
    void connectionTestCompleted(int result, QString blockedPorts);
};

void ComputerModel::testConnectionForComputer(int)
{
    auto* task = new DeferredTestConnectionTask();
    QObject::connect(task, &DeferredTestConnectionTask::connectionTestCompleted,
                     this, &ComputerModel::connectionTestCompleted);
    QThreadPool::globalInstance()->start(task);
}

void ComputerModel::pairComputer(int computerIndex, QString pin)
{
    Q_ASSERT(computerIndex >= 0 && computerIndex < m_Computers.count());
    m_ComputerManager->pairHost(m_Computers[computerIndex], std::move(pin));
}

// ===== change propagation =====
void ComputerModel::handlePairingCompleted(NvComputer*, QString error)
{
    emit pairingCompleted(error.isEmpty() ? QVariant() : QVariant(error));
}

void ComputerModel::handleComputerStateChanged(NvComputer* computer)
{
    QVector<NvComputer*> newList = m_ComputerManager->getComputers();

    if (m_Computers != newList) {
        beginResetModel();
        m_Computers = newList;
        endResetModel();
    } else {
        const int idx = m_Computers.indexOf(computer);
        if (idx >= 0) {
            emit dataChanged(createIndex(idx, 0), createIndex(idx, 0));
        }
    }
}

#include "computermodel.moc"
