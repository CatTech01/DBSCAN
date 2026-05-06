/****************************************************************************
** Meta object code from reading C++ file 'DbscanAlgorithm.h'
**
** Created by: The Qt Meta Object Compiler version 69 (Qt 6.11.0)
**
** WARNING! All changes made in this file will be lost!
*****************************************************************************/

#include "../../../../DbscanAlgorithm.h"
#include <QtCore/qmetatype.h>

#include <QtCore/qtmochelpers.h>

#include <memory>


#include <QtCore/qxptype_traits.h>
#if !defined(Q_MOC_OUTPUT_REVISION)
#error "The header file 'DbscanAlgorithm.h' doesn't include <QObject>."
#elif Q_MOC_OUTPUT_REVISION != 69
#error "This file was generated using the moc from 6.11.0. It"
#error "cannot be used with the include files from this version of Qt."
#error "(The moc has changed too much.)"
#endif

#ifndef Q_CONSTINIT
#define Q_CONSTINIT
#endif

QT_WARNING_PUSH
QT_WARNING_DISABLE_DEPRECATED
QT_WARNING_DISABLE_GCC("-Wuseless-cast")
namespace {
struct qt_meta_tag_ZN15DbscanAlgorithmE_t {};
} // unnamed namespace

template <> constexpr inline auto DbscanAlgorithm::qt_create_metaobjectdata<qt_meta_tag_ZN15DbscanAlgorithmE_t>()
{
    namespace QMC = QtMocConstants;
    QtMocHelpers::StringRefStorage qt_stringData {
        "DbscanAlgorithm",
        "buildSteps",
        "QVariantList",
        "",
        "points",
        "epsilon",
        "minPts",
        "unit",
        "coordinateScaleX",
        "coordinateScaleY",
        "pixelsPerCentimeter",
        "runImmediately",
        "QVariantMap"
    };

    QtMocHelpers::UintData qt_methods {
        // Method 'buildSteps'
        QtMocHelpers::MethodData<QVariantList(const QVariantList &, double, int, const QString &, double, double, double) const>(1, 3, QMC::AccessPublic, 0x80000000 | 2, {{
            { 0x80000000 | 2, 4 }, { QMetaType::Double, 5 }, { QMetaType::Int, 6 }, { QMetaType::QString, 7 },
            { QMetaType::Double, 8 }, { QMetaType::Double, 9 }, { QMetaType::Double, 10 },
        }}),
        // Method 'runImmediately'
        QtMocHelpers::MethodData<QVariantMap(const QVariantList &, double, int, const QString &, double, double, double) const>(11, 3, QMC::AccessPublic, 0x80000000 | 12, {{
            { 0x80000000 | 2, 4 }, { QMetaType::Double, 5 }, { QMetaType::Int, 6 }, { QMetaType::QString, 7 },
            { QMetaType::Double, 8 }, { QMetaType::Double, 9 }, { QMetaType::Double, 10 },
        }}),
    };
    QtMocHelpers::UintData qt_properties {
    };
    QtMocHelpers::UintData qt_enums {
    };
    return QtMocHelpers::metaObjectData<DbscanAlgorithm, qt_meta_tag_ZN15DbscanAlgorithmE_t>(QMC::MetaObjectFlag{}, qt_stringData,
            qt_methods, qt_properties, qt_enums);
}
Q_CONSTINIT const QMetaObject DbscanAlgorithm::staticMetaObject = { {
    QMetaObject::SuperData::link<QObject::staticMetaObject>(),
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN15DbscanAlgorithmE_t>.stringdata,
    qt_staticMetaObjectStaticContent<qt_meta_tag_ZN15DbscanAlgorithmE_t>.data,
    qt_static_metacall,
    nullptr,
    qt_staticMetaObjectRelocatingContent<qt_meta_tag_ZN15DbscanAlgorithmE_t>.metaTypes,
    nullptr
} };

void DbscanAlgorithm::qt_static_metacall(QObject *_o, QMetaObject::Call _c, int _id, void **_a)
{
    auto *_t = static_cast<DbscanAlgorithm *>(_o);
    if (_c == QMetaObject::InvokeMetaMethod) {
        switch (_id) {
        case 0: { QVariantList _r = _t->buildSteps((*reinterpret_cast<std::add_pointer_t<QVariantList>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<double>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[4])),(*reinterpret_cast<std::add_pointer_t<double>>(_a[5])),(*reinterpret_cast<std::add_pointer_t<double>>(_a[6])),(*reinterpret_cast<std::add_pointer_t<double>>(_a[7])));
            if (_a[0]) *reinterpret_cast<QVariantList*>(_a[0]) = std::move(_r); }  break;
        case 1: { QVariantMap _r = _t->runImmediately((*reinterpret_cast<std::add_pointer_t<QVariantList>>(_a[1])),(*reinterpret_cast<std::add_pointer_t<double>>(_a[2])),(*reinterpret_cast<std::add_pointer_t<int>>(_a[3])),(*reinterpret_cast<std::add_pointer_t<QString>>(_a[4])),(*reinterpret_cast<std::add_pointer_t<double>>(_a[5])),(*reinterpret_cast<std::add_pointer_t<double>>(_a[6])),(*reinterpret_cast<std::add_pointer_t<double>>(_a[7])));
            if (_a[0]) *reinterpret_cast<QVariantMap*>(_a[0]) = std::move(_r); }  break;
        default: ;
        }
    }
}

const QMetaObject *DbscanAlgorithm::metaObject() const
{
    return QObject::d_ptr->metaObject ? QObject::d_ptr->dynamicMetaObject() : &staticMetaObject;
}

void *DbscanAlgorithm::qt_metacast(const char *_clname)
{
    if (!_clname) return nullptr;
    if (!strcmp(_clname, qt_staticMetaObjectStaticContent<qt_meta_tag_ZN15DbscanAlgorithmE_t>.strings))
        return static_cast<void*>(this);
    return QObject::qt_metacast(_clname);
}

int DbscanAlgorithm::qt_metacall(QMetaObject::Call _c, int _id, void **_a)
{
    _id = QObject::qt_metacall(_c, _id, _a);
    if (_id < 0)
        return _id;
    if (_c == QMetaObject::InvokeMetaMethod) {
        if (_id < 2)
            qt_static_metacall(this, _c, _id, _a);
        _id -= 2;
    }
    if (_c == QMetaObject::RegisterMethodArgumentMetaType) {
        if (_id < 2)
            *reinterpret_cast<QMetaType *>(_a[0]) = QMetaType();
        _id -= 2;
    }
    return _id;
}
QT_WARNING_POP
