const path = require('path');
const {getDefaultConfig, mergeConfig} = require('@react-native/metro-config');

const root = path.resolve(__dirname, '..');

/**
 * Metro configuration
 * https://reactnative.dev/docs/metro
 *
 * react-native-voicevox is consumed via a local `link:..` dependency, so
 * Metro needs to watch the package root and resolve react/react-native
 * from the example app's node_modules to avoid duplicate copies.
 *
 * @type {import('@react-native/metro-config').MetroConfig}
 */
const config = {
  watchFolders: [root],
  resolver: {
    nodeModulesPaths: [path.resolve(__dirname, 'node_modules')],
    extraNodeModules: {
      react: path.resolve(__dirname, 'node_modules/react'),
      'react-native': path.resolve(__dirname, 'node_modules/react-native'),
      'react-native-nitro-modules': path.resolve(
        __dirname,
        'node_modules/react-native-nitro-modules',
      ),
    },
  },
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
