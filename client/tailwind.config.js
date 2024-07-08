export default {
    content: ['./src/**/*.{astro,gleam,html,js,jsx,md,mdx,svelte,ts,tsx,vue}','./src/*.{astro,gleam,html,js,jsx,md,mdx,svelte,ts,tsx,vue}','./priv/index.html'],
    theme: {
        extend: {
            screens:{
                xxs:'380px',
                xs:'480px'
            },
            colors: {
                'ecru-white': {
                    '50': '#fdfdfb',
                    '100': '#f1f1e3',
                    '200': '#e2e1c6',
                    '300': '#cfcda2',
                    '400': '#bbb47c',
                    '500': '#ada262',
                    '600': '#a09056',
                    '700': '#857549',
                    '800': '#6d5f3f',
                    '900': '#594e35',
                    '950': '#2f281b',
                },
                parchment: {
                    '50': '#f8f6ee',
                    '100': '#eee9d3',
                    '200': '#dfd3a9',
                    '300': '#ccb678',
                    '400': '#bc9c53',
                    '500': '#ad8a45',
                    '600': '#946e3a',
                    '700': '#775331',
                    '800': '#65452e',
                    '900': '#573c2c',
                    '950': '#321f16',
                },

                orchid: {
                    '50': '#fdf2fb',
                    '100': '#fce7f8',
                    '200': '#fad0f3',
                    '300': '#f8a9e8',
                    '400': '#f165d2',
                    '500': '#ea4ac2',
                    '600': '#d929a4',
                    '700': '#bc1a86',
                    '800': '#9b196e',
                    '900': '#82195e',
                    '950': '#4f0836',
                },
                'granny-apple': {
                    '50': '#f1fcf8',
                    '100': '#d4f7eb',
                    '200': '#a2edd4',
                    '300': '#6cdcbc',
                    '400': '#3dc4a1',
                    '500': '#24a888',
                    '600': '#1a876f',
                    '700': '#196c5a',
                    '800': '#19564a',
                    '900': '#19483f',
                    '950': '#082b25',
                },
                'fruit-salad': {
                    '50': '#f4f9f4',
                    '100': '#e5f3e7',
                    '200': '#cbe7d0',
                    '300': '#a3d2ab',
                    '400': '#72b67e',
                    '500': '#509c5e',
                    '600': '#3c7d48',
                    '700': '#32633b',
                    '800': '#2b5032',
                    '900': '#25422c',
                    '950': '#102315',
                },

                anakiwa: {
                    '50': '#f2fafd',
                    '100': '#e3f3fb',
                    '200': '#c1e9f6',
                    '300': '#9edef1',
                    '400': '#4dc3e3',
                    '500': '#26acd1',
                    '600': '#178cb2',
                    '700': '#147090',
                    '800': '#155e77',
                    '900': '#174e63',
                    '950': '#0f3342',
                },
                punch: {
                    '50': '#fff2f1',
                    '100': '#ffe4e1',
                    '200': '#ffccc7',
                    '300': '#ffa9a1',
                    '400': '#ff776a',
                    '500': '#f84c3b',
                    '600': '#e52c1a',
                    '700': '#c12314',
                    '800': '#9f2115',
                    '900': '#842218',
                    '950': '#480d07',
                }
            }
        },
    },
    corePlugins: {
        fontSize: false,
    },
    plugins: [
        require('tailwindcss-fluid-type')({
            // your fluid type settings
            // works only with unitless numbers
            // This numbers are the defaults settings
            settings: {
              fontSizeMin: 1.125, // 1.125rem === 18px
              fontSizeMax: 1.25, // 1.25rem === 20px
              ratioMin: 1.125, // Multiplicator Min
              ratioMax: 1.2, // Multiplicator Max
              screenMin: 20, // 20rem === 320px
              screenMax: 96, // 96rem === 1536px
              unit: "rem", // default is rem but it's also possible to use 'px'
              prefix: "", // set a prefix to use it alongside the default font sizes
              extendValues: true, // When you set extendValues to true it will extend the default values. Set it to false to overwrite the values.
            },
            // Creates the text-xx classes
            // This are the default settings and analog to the tailwindcss defaults
            // Each `lineHeight` is set unitless and we think that's the way to go especially in context with fluid type.
            values: {
              xs: [-2, 1.6],
              sm: [-1, 1.6],
              base: [0, 1.6],
              lg: [1, 1.6],
              xl: [2, 1.2],
              "2xl": [3, 1.2],
              "3xl": [4, 1.2],
              "4xl": [5, 1.1],
              "5xl": [6, 1.1],
              "5.5xl": [6.3, 1.1],
              "6xl": [7, 1.1],
              "7xl": [8, 1],
              "8xl": [9, 1],
              "9xl": [10, 1],
            },
          }),
        ({ addComponents, addUtilities }) => {
            addComponents({

                '.wrapper': {
                    display: 'grid',
                    'grid-template-columns': '1fr min(85ch, 100%) 1fr',
                },
                '.wrapper > *': {
                    'grid-column': '2'
                },
                '.wrapper > * > *': {
                    'grid-column': '2'
                },
                '.under-highlight': {
                    'box-shadow': 'inset 0 -6px 0 #fce7f8'
                },
                '.subgrid-cols': {
                    display: 'grid',
                    'grid-template-columns': 'subgrid'
                },
                '.subgrid-rows': {
                    display: 'grid',
                    'grid-template-rows': 'subgrid'
                },
                '.grid-rows-auto': {
                    gridAutoRows: 'minmax(100px, max-content)'
                },
                'input[type="number"]': {
                    '&::-webkit-inner-spin-button': {
                        '-webkit-appearance': 'none',
                        margin: 0
                    },
                    '&::-webkit-outer-spin-button': {
                        '-webkit-appearance': 'none',
                        margin: 0
                    },
                    '-moz-appearance': 'textfield'
                },
                'input-base': {
                    borderWidth: '0px',
                    borderBottomWidth: '0px',
                    paddingTop: '0px',
                    paddingBottom: '0px',
                    lineHeight: 'inherit',
                    backgroundColor: 'transparent',
                },
                textarea:{
                    borderWidth: '0px',
                    borderBottomWidth: '0px',
                    paddingTop: '0px',
                    paddingBottom: '0px',
                    lineHeight: 'inherit',
                    backgroundColor: 'transparent',
                },
                '.input-focus:focus': {
                    outline: '2px solid transparent',
                    outlineOffset: '2px',
                    '--tw-ring-offset-shadow': 'var(--tw-ring-inset) 0 0 0 var(--tw-ring-offset-width) var(--tw-ring-offset-color)',
                    '--tw-ring-shadow': 'var(--tw-ring-inset) 0 0 0 calc(0px + var(--tw-ring-offset-width)) var(--tw-ring-color)',
                    boxShadow: 'var(--tw-ring-offset-shadow), var(--tw-ring-shadow), var(--tw-shadow, 0 0 #0000)',
                    '--tw-border-opacity': '1',
                    'border-color': 'rgb(80 156 94 / var(--tw-border-opacity))',
                    borderWidth: '0px',
                    borderBottomWidth: '1px',
                },
                'textarea:focus': {
                    outline: '2px solid transparent',
                    outlineOffset: '2px',
                    '--tw-ring-offset-shadow': 'var(--tw-ring-inset) 0 0 0 var(--tw-ring-offset-width) var(--tw-ring-offset-color)',
                    '--tw-ring-shadow': 'var(--tw-ring-inset) 0 0 0 calc(0px + var(--tw-ring-offset-width)) var(--tw-ring-color)',
                    boxShadow: 'var(--tw-ring-offset-shadow), var(--tw-ring-shadow), var(--tw-shadow, 0 0 #0000)',
                    '--tw-border-opacity': '1',
                    'border-color': 'rgb(80 156 94 / var(--tw-border-opacity))',
                    borderWidth: '0px',
                    borderBottomWidth: '1px',
                },
                '.input-outline': {
                    '--tw-border-opacity': '1',
                    'border-color': 'rgb(80 156 94 / var(--tw-border-opacity))',
                    borderWidth: '0px',
                    borderBottomWidth: '1px',
                },
                '.under-gradient': {
                    background: 'linear-gradient(to left, #fce7f8, #fce7f8 100%)',
                    backgroundPosition: '0 100%',
                    backgroundSize: '100% 6px',
                    backgroundRepeat: 'repeat-x',
                },
                '.underline-pink': {
                    textDecoration: 'underline solid 6px #fce7f8'
                },
                '.underline-orange': {
                    textDecoration: 'underline solid 6px #ff776a'
                },
                '.underline-green': {
                    textDecoration: 'underline solid 6px #a3d2ab'
                },
                '.underline-blue': {
                    textDecoration: 'underline solid 6px #9edef1'
                },
                '.underline-yellow': {
                    textDecoration: 'underline solid 6px #fce68b'
                },
                '.underline-dark-blue': {
                    textDecoration: 'underline solid 6px #287CA1'
                },
                '.shadow-orange': {
                    boxShadow:'1px 1px 0 #ff776a'
                },
                '.custom-select': {
                    '-webkit-appearance': 'none;',
                    '-moz-appearance': 'none;',
                    width: '100%;',
                    background: 'rgb(253 253 251);',
                    '--tw-border-opacity': '1',
                    'border-color': 'rgb(80 156 94 / var(--tw-border-opacity))',
                    borderWidth: '1px',
                    cursor: 'pointer;'

                },
                fieldset: {
                    minWidth: 0,
                },
                ".ingredient-toggle": {
                    display: "inline-flex",
                    cursor: "pointer"
                },
                ".ingredient-toggle > input": {
                    "-webkit-appearance": "none",
                    "-moz-appearance": "none",
                    "-o-appearance": "none",
                    appearance: "none",
                    cursor: "pointer",
                  },
                ".ingredient-toggle > span": {
                    display: "contents",
                  }
                ,".ingredient-toggle > input + span::before": {
                    content: "'❕'",
                    alignSelf:"baseline",
                  }
                ,".ingredient-toggle > input:checked + span::before" : {
                    content: "'❗'",
                    alignSelf:"baseline",
                  }
                 
            })
            addUtilities({
                '.font-transitional':{
                    'font-family':"Charter, 'Bitstream Charter', 'Sitka Text', Cambria, serif"
                },
                '.font-old-style':{
                    'font-family':"'Iowan Old Style', 'Palatino Linotype', 'URW Palladio L', P052, serif"
                },
                '.font-mono':{
                    'font-family':"ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace"
                },
            })
        }
    ],
}