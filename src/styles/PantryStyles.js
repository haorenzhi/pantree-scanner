import styled from 'styled-components';

export const MainLayout = styled.div`
        height: 100vh;
        width: 100%;
        display: flex;
        align-items: center;
        position: fixed; 
        flex-direction: column;
        background:rgba(245, 243, 240, 0.6);
        z-index: 0;
    `

export const Header = styled.div`
        display: flex;
        width: 75%;
        height: 12%;
        flex-direction: row;
        align-items: left;
        margin-bottom: 20px;
        justify-content: center;
    `

export const H1 = styled.p`
        font-family: Raleway;
        font-style: italic;
        font-weight: 900;
        font-size: 32px;
        line-height: 38px;
        margin-top: 50px;
        color: #000000;
    `

export const H2 = styled.p`
        font-family: Raleway;
        font-style: italic;
        font-weight: 600;
        font-size: 20px;
        line-height: 38px;
        margin-top: 50px;
        color: #b6b6b6;
        justify-content: center;
    `

export const Content = styled.div`
        display: flex;
        flex-direction: column;
        justify-content: top;
        align-items: center;
        width: 100%;
        height: 88%;
        overflow-y: auto;
        margin-top: 20px;
    `

export const ItemCard = styled.div`
    display: grid;
    width: 100%;
    max-width: 18%;
    min-width: 320px;
    height: 160px;
    box-shadow: 4px 4px 10px 5px rgba(57, 57, 57, 0.1);
    border-radius: 15px;
    margin-bottom: 27px;
    grid-template-columns: 30% 50% 20%;
    grid-template-rows: 60% 15% 25%;
    grid-template-areas: 
        'txt item-name delete'
        'txt purchase-date purchase-date'
        'txt exp-date edit';
    background: ${({ color }) => handleColorType(color)};
    margin: 2%;
`

export const ItemImg = styled.h1`
        text-align: center;
        display: flex;
        align-items: center;
        justify-content: center;
        grid-area: txt;
        font-size: 60px
    `

export const ItemName = styled.p`
        grid-area: item-name; 
        font-family: Quicksand;
        font-style: normal;
        font-weight: 600;
        font-size: 24px;
        margin-top: 23px;
        align-self: center;
        color: #000000;
        line-height: 29px;
        text-transform: capitalize;
        overflow-wrap: break-word;
        ${({ active }) => active && `
        color: red;
      `}
    `

export const DeleteButton = styled.p`
    grid-area: delete; 
    font-family: Quicksand;
    font-style: normal;
    font-weight: 500;
    font-size: 14px;
    color: #989898;
    align-self: center;
    padding: 8px;
    padding-top: 15px;
`

export const EditButton = styled.p`
    grid-area: edit; 
    font-family: Quicksand;
    font-style: normal;
    font-weight: 500;
    font-size: 14px;
    color: #989898;
    align-self: center;
    padding: 8px;
`

export const PurchaseDate = styled.p`
        grid-area: purchase-date; 
        font-family: Quicksand;
        font-style: normal;
        font-weight: 500;
        font-size: 14px;
        color: #989898;
    `

export const ExpDate = styled.p`
    grid-area: exp-date; 
    font-family: Quicksand;
    font-style: normal;
    // font-weight: bold;
    font-size: 14px;
    align-self: top;
    color: #989898;
`

const handleColorType = color => {
    switch (color) {
      case 2: // not gonna expire soon
        return "#c9d9c5";
      case 1: // about to expire
        return "#FFE8B7";
      case 0: //expired
        return "#FFD6C2";
        
      default:
        return "#fff"
    }
  };