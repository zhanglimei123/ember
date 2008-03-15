#pragma once

#include <cantera/Cantera.h>
#include <cantera/IdealGasMix.h>    // defines class IdealGasMix
#include <cantera/equilibrium.h>    // chemical equilibrium
#include <cantera/thermo.h>
#include <cantera/transport.h>      // transport properties
#include <cantera/kinetics.h>

#include <cantera/kernel/IdealGasPhase.h>
#include <cantera/kernel/GasKinetics.h>
#include <cantera/kernel/ctml.h>

#include "mathUtils.h"

class gasArray
{
public:
	gasArray();
	~gasArray();
	std::string mechanismFile;
	std::string phaseID;
	double pressure; // thermodynamic pressure
	
	void initialize(void);
	void resize(unsigned int n);
	
	void setState(Cantera::Array2D& Y, dvector& T);
	void getViscosity(dvector& mu);
	void getThermalConductivity(dvector& lambda);
	void getDiffusionCoefficients(Cantera::Array2D& Dkm);
	void getSpecificHeatCapacity(dvector& cp);

	Cantera::IdealGasPhase& operator[](unsigned int i) const;
	Cantera::IdealGasPhase& thermo(unsigned int i) const;
	Cantera::GasKinetics& kinetics(unsigned int i) const;
	Cantera::MultiTransport& trans(unsigned int i) const;

	void testFunction(void);

private:
	Cantera::XML_Node* rootXmlNode;
	Cantera::XML_Node* phaseXmlNode;

	int nPoints;

	vector<Cantera::IdealGasPhase*> m_thermo;
	vector<Cantera::GasKinetics*> m_kinetics;
	vector<Cantera::MultiTransport*> m_transport;

	// Default objects
	Cantera::IdealGasPhase m_thermoBase;
	Cantera::GasKinetics* m_kineticsBase;
	Cantera::MultiTransport* m_transportBase;
};