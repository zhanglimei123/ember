#cython: embedsignature=True
#distutils: language = c++

import numpy as np
cimport numpy as np
import os

from cython.operator cimport dereference as deref
from _ember cimport *

cdef class ConfigOptions:
    def __cinit__(self, *args, **kwargs):
        self.opts = new CxxConfigOptions()

    def __dealloc__(self):
        del self.opts

    def apply_options(self):
        cdef CxxConfigOptions* opts = self.opts

        def get(option, default):
            if option is None:
                return default, False
            else:
                return option, True

        # Paths
        opts.outputDir = self.paths.outputDir
        if self.paths.logFile is not None:
            CxxSingletonLogfile.open(self.paths.logFile)
        if not os.path.exists(opts.outputDir):
            os.makedirs(opts.outputDir)

        # General
        G = self.general
        opts.fixedBurnedVal = G.fixedBurnedVal
        opts.fixedLeftLoc = G.fixedLeftLocation
        opts.unburnedLeft = G.unburnedLeft
        opts.fuelLeft = G.fuelLeft
        opts.nThreads = G.nThreads
        opts.curvedFlame = G.curvedFlame
        opts.gridAlpha = 1 if opts.curvedFlame else 0
        opts.twinFlame = G.twinFlame
        if G.interpFile is not None:
            opts.interpFile = G.interpFile
        opts.chemistryIntegrator = G.chemistryIntegrator
        opts.splittingMethod = G.splittingMethod
        opts.setContinuityBC(G.continuityBC)
        opts.errorStopCount = G.errorStopCount
        opts.stopIfError = G.errorStopCount > 0

        # Chemistry
        opts.gasMechanismFile = self.chemistry.mechanismFile
        opts.gasPhaseID = self.chemistry.phaseID
        opts.transportModel = self.chemistry.transportModel
        opts.transportThreshold = self.chemistry.threshold

        # Initial condition
        IC = self.initialCondition
        opts.restartFile, opts.haveRestartFile = get(IC.restartFile, '')

        opts.haveInitialProfiles = IC.haveProfiles
        cdef np.ndarray[np.double_t, ndim=1] data
        cdef np.ndarray[np.double_t, ndim=2] Y
        if opts.haveInitialProfiles:
            data = np.ascontiguousarray(IC.x)
            opts.x_initial = map_vector(&data[0], len(data), 1)

            data = np.ascontiguousarray(IC.T)
            opts.T_initial = map_vector(&data[0], len(data), 1)

            data = np.ascontiguousarray(IC.U)
            opts.U_initial = map_vector(&data[0], len(data), 1)

            # Numpy defaults to row major; Eigen is column major
            Y = np.ascontiguousarray(IC.Y.T)
            w, h = Y.shape[0], Y.shape[1]
            opts.Y_initial = map_matrix(&Y[0,0], h, w, h, 1)

            opts.rVzero_initial = IC.rVzero

        # Inlet mixture conditions
        opts.Tu, opts.overrideTu = get(IC.Tu, 0)
        opts.fuel, opts.overrideReactants = get(IC.fuel, '')
        opts.flameType = IC.flameType
        opts.oxidizer = IC.oxidizer
        opts.Tfuel = IC.Tfuel
        opts.Toxidizer = IC.Toxidizer
        opts.equivalenceRatio = IC.equivalenceRatio
        opts.pressure = IC.pressure
        opts.quasi2d = IC.flameType == 'quasi2d'

        # Wall flux boundary condition
        if self.wallFlux:
            opts.wallFlux = True
            opts.Tinf = self.wallFlux.Tinf
            opts.Kwall = self.wallFlux.Kwall
        else:
            opts.wallFlux = 0
            opts.Tinf = opts.Tu
            opts.Kwall = 0

        # ignition parameters
        opts.ignition_tStart = self.ignition.tStart
        opts.ignition_duration = self.ignition.duration
        opts.ignition_energy = self.ignition.energy
        opts.ignition_center = self.ignition.center
        opts.ignition_stddev = self.ignition.stddev

        # strain rate parameters
        opts.strainRateInitial = self.strainParameters.initial
        opts.strainRateFinal = self.strainParameters.final
        opts.strainRateT0 = self.strainParameters.tStart
        opts.strainRateDt = self.strainParameters.dt

        # Flame position control
        if self.positionControl is not None:
            PC = self.positionControl
            opts.xStagControl = True
            opts.xFlameControl = True
            opts.xFlameInitial = PC.xInitial
            opts.xFlameFinal = PC.xFinal
            opts.xFlameT0 = PC.tStart
            opts.xFlameDt = PC.dt
            opts.xFlameIntegralGain = PC.integralGain
            opts.xFlameProportionalGain = PC.proportionalGain
        else:
            opts.xStagControl = False
            opts.xFlameControl = False

        # Grid
        opts.centerGridMin = self.grid.centerGridMin
        opts.vtol = self.grid.vtol
        opts.dvtol = self.grid.dvtol
        opts.rmTol = self.grid.rmTol
        opts.dampConst = self.grid.dampConst
        opts.gridMax = self.grid.gridMax
        opts.gridMin = self.grid.gridMin
        opts.uniformityTol = self.grid.uniformityTol
        opts.absvtol = self.grid.absvtol
        opts.boundaryTol = self.grid.boundaryTol
        opts.boundaryTolRm = self.grid.boundaryTolRm
        opts.addPointCount = self.grid.addPointCount
        opts.unstrainedDownstreamWidth = self.grid.unstrainedDownstreamWidth

        # Times
        opts.tStart, opts.haveTStart = get(self.times.tStart, 0.0)
        opts.regridTimeInterval = self.times.regridTimeInterval
        opts.regridStepInterval = self.times.regridStepInterval
        opts.outputTimeInterval = self.times.outputTimeInterval
        opts.outputStepInterval = self.times.outputStepInterval
        opts.profileTimeInterval = self.times.profileTimeInterval
        opts.profileStepInterval = self.times.profileStepInterval
        opts.currentStateStepInterval = self.times.currentStateStepInterval
        opts.terminateStepInterval = self.times.terminateStepInterval
        opts.globalTimestep = self.times.globalTimestep
        opts.diffusionTimestepMultiplier = self.times.diffusionTimestepMultiplier

        # Debugging options
        CxxSetDebugParameters(self.debug.adaptation,
                              self.debug.regridding,
                              self.debug.timesteps,
                              self.debug.flameRadiusControl,
                              self.debug.veryVerbose)

        opts.debugSourcePoint = self.debug.sourcePoint
        opts.debugSourceTime = self.debug.sourceTime
        opts.debugStartTime = self.debug.startTime
        opts.debugStopTime = self.debug.stopTime

        # CVODE options
        CVODE = self.cvodeTolerances
        opts.integratorRelTol = CVODE.relativeTolerance
        opts.integratorMomentumAbsTol = CVODE.momentumAbsTol
        opts.integratorEnergyAbsTol = CVODE.energyAbsTol
        opts.integratorSpeciesAbsTol = CVODE.speciesAbsTol
        opts.integratorMinTimestep = CVODE.minimumTimestep

        # QSS integrator options
        QSS = self.qssTolerances
        opts.qss_epsmax = QSS.epsmax
        opts.qss_epsmin = QSS.epsmin
        opts.qss_dtmin = QSS.dtmin
        opts.qss_dtmax = QSS.dtmax
        opts.qss_iterationCount = QSS.iterationCount
        opts.qss_abstol = QSS.abstol
        opts.qss_minval = QSS.minval
        opts.qss_stabilityCheck = QSS.stabilityCheck

        # Output files
        opts.outputProfiles = self.outputFiles.saveProfiles
        if self.outputFiles.saveProfiles:
            opts.outputHeatReleaseRate = self.outputFiles.heatReleaseRate
            opts.outputAuxiliaryVariables = self.outputFiles.auxiliaryVariables
            opts.outputTimeDerivatives = self.outputFiles.timeDerivatives
            opts.outputExtraVariables = self.outputFiles.extraVariables
            opts.outputFileNumber, opts.fileNumberOverride = \
                get(self.outputFiles.firstFileNumber, 0)

        # Termination Conditions
        TC = self.terminationCondition
        opts.tEnd = TC.tEnd
        opts.terminateForSteadyQdot = TC.measurement == 'Q'
        if opts.terminateForSteadyQdot:
            opts.terminationPeriod = TC.steadyPeriod
            opts.terminationTolerance = TC.tolerance
            opts.terminationAbsTol = TC.abstol


cdef class FlameSolver:
    def __cinit__(self, *args, **kwargs):
        self.solver = new CxxFlameSolver()

    def __init__(self, ConfigOptions options):
        self.options = options # keep to prevent garbage collection
        options.evaluate()
        options.apply_options()
        self.solver.setOptions(deref(options.opts))

    def __dealloc__(self):
        del self.solver

    def initialize(self):
        self.solver.initialize()

    def finalize(self):
        self.solver.finalize()

    def step(self):
        return self.solver.step()