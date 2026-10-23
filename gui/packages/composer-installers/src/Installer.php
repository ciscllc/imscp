<?php

namespace iMSCP\Composer;

use Composer\Composer;
use Composer\Installer\BinaryInstaller;
use Composer\Installer\LibraryInstaller;
use Composer\IO\IOInterface;
use Composer\Package\PackageInterface;
use Composer\Repository\InstalledRepositoryInterface;
use Composer\Util\Filesystem;

class Installer extends LibraryInstaller
{
    private $supportedTypes = [
        'imscp' => 'ImscpInstaller',
        'roundcube' => 'RoundcubeInstaller'
    ];

    public function __construct(
        IOInterface $io,
        Composer $composer,
        $type = 'library',
        Filesystem $filesystem = null,
        BinaryInstaller $binaryInstaller = null
    ) {
        parent::__construct($io, $composer, $type, $filesystem, $binaryInstaller);
        $this->removeDisabledInstallers();
    }

    protected function removeDisabledInstallers(): void
    {
        $extra = $this->composer->getPackage()->getExtra();
        if (!isset($extra['installer-disable']) || $extra['installer-disable'] === false) {
            return;
        }

        $disable = is_array($extra['installer-disable']) ? $extra['installer-disable'] : [$extra['installer-disable']];
        if (array_intersect([true, 'all', '*'], $disable)) {
            $this->supportedTypes = [];
            return;
        }

        foreach ($disable as $installer) {
            if (is_string($installer) && array_key_exists($installer, $this->supportedTypes)) {
                unset($this->supportedTypes[$installer]);
            }
        }
    }

    public function getInstallPath(PackageInterface $package)
    {
        $type = $package->getType();
        $installerType = $this->findInstallerType($type);
        if ($installerType === false) {
            throw new \InvalidArgumentException('The package type of this package is not supported.');
        }

        $class = 'iMSCP\\Composer\\' . $this->supportedTypes[$installerType];
        $installer = new $class($package, $this->composer, $this->io);
        return $installer->getInstallPath($package, $installerType);
    }

    protected function findInstallerType($type)
    {
        krsort($this->supportedTypes);
        foreach ($this->supportedTypes as $key => $val) {
            if ($key === substr($type, 0, strlen($key))) {
                return substr($type, 0, strlen($key));
            }
        }
        return false;
    }

    public function uninstall(InstalledRepositoryInterface $repo, PackageInterface $package)
    {
        parent::uninstall($repo, $package);
        $installPath = $this->getPackageBasePath($package);
        $this->io->write(sprintf(
            'Deleting %s - %s',
            $installPath,
            !file_exists($installPath) ? '<comment>deleted</comment>' : '<error>not deleted</error>'
        ));
    }

    public function supports($packageType)
    {
        $installerType = $this->findInstallerType($packageType);
        if ($installerType === false) {
            return false;
        }

        $installerClass = 'iMSCP\\Composer\\' . $this->supportedTypes[$installerType];
        $installer = new $installerClass(null, $this->composer, $this->io);
        $locations = array_keys($installer->getLocations());
        $locationPattern = $locations ? '(' . implode('|', $locations) . ')' : '(\\w+)';

        return preg_match('#' . $installerType . '-' . $locationPattern . '#', $packageType) === 1;
    }
}
